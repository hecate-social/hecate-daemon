%%% @doc Unix-socket listener for post-receive hook notifications.
%%%
%%% Opens `gen_tcp:listen/2` on `{local, SockPath}`. Each accepted
%%% connection is handled inline — parsing is cheap, payloads are tiny,
%%% and the hook is one-shot per ref update.
%%%
%%% Line format:
%%%
%%%   `<repo_id> <old_sha> <new_sha> <ref_name>\n`
%%%
%%% Missing or malformed lines are logged and dropped.
%%% @end
-module(receive_ref_update_rpc).
-behaviour(gen_server).

-export([start_link/0, socket_path/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    listen_socket :: gen_tcp:socket() | undefined,
    socket_path   :: file:filename()
}).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec socket_path() -> file:filename().
socket_path() ->
    post_receive_script:socket_path().

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    process_flag(trap_exit, true),
    SockPath = socket_path(),
    ok = ensure_socket_dir(SockPath),
    _  = file:delete(SockPath),  %% stale socket from a prior run
    ListenOpts = [
        {ifaddr, {local, SockPath}},
        binary,
        {packet, line},
        {active, false},
        {reuseaddr, true}
    ],
    case gen_tcp:listen(0, ListenOpts) of
        {ok, LSock} ->
            _ = file:change_mode(SockPath, 8#600),
            logger:info("[receive_ref_update_rpc] Listening on ~s", [SockPath]),
            self() ! accept_next,
            {ok, #state{listen_socket = LSock, socket_path = SockPath}};
        {error, Reason} ->
            logger:warning("[receive_ref_update_rpc] Failed to listen on ~s: ~p — "
                           "post-receive FACTs disabled on this node",
                           [SockPath, Reason]),
            {ok, #state{listen_socket = undefined, socket_path = SockPath}}
    end.

handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(accept_next, #state{listen_socket = undefined} = State) ->
    {noreply, State};
handle_info(accept_next, #state{listen_socket = LSock} = State) ->
    Server = self(),
    _ = spawn_link(fun() -> accept_loop(Server, LSock) end),
    {noreply, State};
handle_info({line, Line}, State) ->
    handle_line(Line),
    {noreply, State};
handle_info({'EXIT', _Pid, _Reason}, #state{listen_socket = undefined} = State) ->
    {noreply, State};
handle_info({'EXIT', _Pid, _Reason}, State) ->
    %% Acceptor exited (normal after single accept) — schedule next.
    self() ! accept_next,
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{listen_socket = LSock, socket_path = Path}) ->
    catch gen_tcp:close(LSock),
    _ = file:delete(Path),
    ok.

%%====================================================================
%% Internal
%%====================================================================

accept_loop(Server, LSock) ->
    case gen_tcp:accept(LSock, infinity) of
        {ok, Sock} ->
            read_lines(Server, Sock),
            catch gen_tcp:close(Sock),
            Server ! accept_next;
        {error, closed} ->
            ok;
        {error, Reason} ->
            logger:warning("[receive_ref_update_rpc] accept failed: ~p", [Reason]),
            Server ! accept_next
    end.

read_lines(Server, Sock) ->
    case gen_tcp:recv(Sock, 0, 5000) of
        {ok, Line} ->
            Server ! {line, Line},
            read_lines(Server, Sock);
        {error, closed} -> ok;
        {error, timeout} -> ok;
        {error, _} -> ok
    end.

handle_line(Line) ->
    Trimmed = strip_newline(Line),
    case binary:split(Trimmed, <<" ">>, [global, trim_all]) of
        [RepoId, OldSha, NewSha, RefName] ->
            publish_ref_updated_fact:publish(RepoId, OldSha, NewSha, RefName);
        Parts ->
            logger:warning("[receive_ref_update_rpc] Malformed line (~p parts): ~p",
                           [length(Parts), Trimmed])
    end.

strip_newline(Bin) ->
    case binary:last(Bin) of
        $\n -> binary:part(Bin, 0, byte_size(Bin) - 1);
        _   -> Bin
    end.

ensure_socket_dir(Path) ->
    filelib:ensure_path(filename:dirname(Path)).
