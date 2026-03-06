%%% @doc Plugin container watcher.
%%%
%%% Polls installed plugin sockets every few seconds.
%%% When a socket appears (container up) or disappears (container down),
%%% dispatches the corresponding confirm command to close the feedback loop.
%%%
%%% This catches both expected transitions (after start/stop) and
%%% unexpected ones (container crash).
%%% @end
-module(plugin_container_watcher).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(POLL_INTERVAL_MS, 5000).

-record(state, {
    %% plugin_id => up | down
    known :: #{binary() => up | down}
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    erlang:send_after(?POLL_INTERVAL_MS, self(), poll),
    {ok, #state{known = #{}}}.

handle_info(poll, State) ->
    NewState = do_poll(State),
    erlang:send_after(?POLL_INTERVAL_MS, self(), poll),
    {noreply, NewState};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

do_poll(#state{known = Known} = State) ->
    case query_installed_plugins() of
        {ok, Plugins} ->
            NewKnown = lists:foldl(
                fun({PluginId, OciImage}, Acc) ->
                    check_plugin(PluginId, OciImage, Acc, Known)
                end, Known, Plugins),
            State#state{known = NewKnown};
        {error, _} ->
            State
    end.

check_plugin(PluginId, OciImage, Acc, Known) ->
    DaemonName = extract_daemon_name(OciImage),
    SocketPath = plugin_socket_path(DaemonName),
    CurrentStatus = case filelib:is_regular(SocketPath) of
        true -> up;
        false -> down
    end,
    PreviousStatus = maps:get(PluginId, Known, undefined),
    handle_transition(PluginId, PreviousStatus, CurrentStatus),
    maps:put(PluginId, CurrentStatus, Acc).

handle_transition(_PluginId, Same, Same) ->
    ok;
handle_transition(_PluginId, undefined, _Current) ->
    %% First poll — establish baseline, don't dispatch
    ok;
handle_transition(PluginId, _Previous, up) ->
    dispatch_confirm_up(PluginId);
handle_transition(PluginId, _Previous, down) ->
    dispatch_confirm_down(PluginId).

dispatch_confirm_up(PluginId) ->
    case confirm_container_up_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_confirm_container_up:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[watcher] Container confirmed UP for ~s", [PluginId]);
                {error, Reason} ->
                    logger:warning("[watcher] Failed to confirm UP for ~s: ~p",
                                   [PluginId, Reason])
            end;
        {error, _} -> ok
    end.

dispatch_confirm_down(PluginId) ->
    case confirm_container_down_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_confirm_container_down:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[watcher] Container confirmed DOWN for ~s", [PluginId]);
                {error, Reason} ->
                    logger:warning("[watcher] Failed to confirm DOWN for ~s: ~p",
                                   [PluginId, Reason])
            end;
        {error, _} -> ok
    end.

query_installed_plugins() ->
    Sql = "SELECT plugin_id, oci_image FROM plugins WHERE (status & 2) = 0",
    try project_plugins_store:query(Sql) of
        {ok, Rows} ->
            {ok, [row_to_tuple(R) || R <- Rows]};
        {error, _} = Err ->
            Err
    catch
        exit:{noproc, _} -> {error, store_not_ready};
        exit:{timeout, _} -> {error, store_timeout}
    end.

row_to_tuple([PluginId, OciImage]) -> {PluginId, OciImage};
row_to_tuple({PluginId, OciImage}) -> {PluginId, OciImage}.

plugin_socket_path(DaemonName) ->
    HecateHome = shared_paths:hecate_home(),
    filename:join([HecateHome, DaemonName, "sockets", "api.sock"]).

extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case binary:matches(Base, <<"/">>) of
        [] -> Base;
        Matches ->
            {Pos, Len} = lists:last(Matches),
            binary:part(Base, Pos + Len, byte_size(Base) - Pos - Len)
    end.

strip_tag(Image) ->
    case binary:matches(Image, <<":">>) of
        [] -> Image;
        Matches ->
            {Pos, _} = lists:last(Matches),
            Tag = binary:part(Image, Pos + 1, byte_size(Image) - Pos - 1),
            case binary:match(Tag, <<"/">>) of
                nomatch -> binary:part(Image, 0, Pos);
                _ -> Image
            end
    end.
