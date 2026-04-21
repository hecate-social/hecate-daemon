%%% @doc Mesh listener for `<realm>.briefcase.file_shared` FACTs.
%%%
%%% When another peer in the realm publishes a `file_shared` FACT, we
%%% dispatch an `announce_file_v1` command. The aggregate writes a
%%% `file_announced_v1` event and the projection creates a
%%% `remote + placeholder` row in the briefcase read model.
%%%
%%% Content is NOT fetched here — that's the `file_cached_v1`
%%% transition (Phase E of PLAN_BRIEFCASE_PRESENCE_PRIVACY). Phase B
%%% stops at the placeholder so peers can see each other's shared
%%% files without any transfer.
%%% @end
-module(listen_for_shared_files).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    realm :: binary(),
    topic :: binary()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Topic = <<Realm/binary, ".briefcase.file_shared">>,
    Self  = self(),
    Callback = fun(Fact) ->
        Self ! {shared_fact, Fact},
        ok
    end,
    hecate_mesh_client:register_subscription(Topic, Callback),
    logger:info("[briefcase] subscribed to mesh topic ~s", [Topic]),
    {ok, #state{realm = Realm, topic = Topic}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)        -> {noreply, State}.

handle_info({shared_fact, Fact}, State) ->
    _ = process_fact(Fact),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.

%%% ===================================================================
%%% Internal
%%% ===================================================================

process_fact(Fact) ->
    case to_command_payload(Fact) of
        {ok, Payload} ->
            dispatch_announce(Payload);
        {error, Reason} ->
            logger:warning("[briefcase] malformed shared fact: ~p (~p)",
                           [Fact, Reason]),
            ok
    end.

dispatch_announce(Payload) ->
    Cmd = announce_file_v1:new(Payload),
    case maybe_announce_file:dispatch(Cmd) of
        {ok, _Ver, _Events} ->
            logger:info("[briefcase] announced remote file ~s",
                        [maps:get(file_id, Payload)]),
            ok;
        {error, already_present} ->
            %% Idempotent — we've already recorded this file.
            ok;
        {error, Reason} ->
            logger:warning("[briefcase] announce dispatch failed for ~s: ~p",
                           [maps:get(file_id, Payload), Reason]),
            {error, Reason}
    end.

to_command_payload(Fact) ->
    FileId = gf(file_id, Fact),
    Realm  = gf(realm,   Fact),
    Path   = gf(path,    Fact),
    case {FileId, Realm, Path} of
        {undefined, _, _} -> {error, no_file_id};
        {_, undefined, _} -> {error, no_realm};
        {_, _, undefined} -> {error, no_path};
        _ ->
            {ok, #{
                file_id      => FileId,
                realm        => Realm,
                path         => Path,
                mime_type    => gf(mime_type,    Fact),
                size         => gf(size,         Fact),
                content_hash => gf(content_hash, Fact),
                author_did   => gf(author_did,   Fact),
                announced_at => gf(shared_at,    Fact,
                                   erlang:system_time(millisecond))
            }}
    end.

gf(Key, Map) -> gf(Key, Map, undefined).
gf(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
