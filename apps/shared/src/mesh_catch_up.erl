%%%-------------------------------------------------------------------
%%% @doc Mesh catch-up subscriptions — event store replay via RPC.
%%%
%%% Two roles:
%%%
%%% **Producer**: CMD apps that emit integration facts to mesh call
%%% `advertise_replay/3` to expose a catch-up RPC. Remote consumers
%%% call it to replay events they missed while offline.
%%%
%%% **Consumer**: Apps that subscribe to mesh integration facts call
%%% `catch_up/4` on reconnect to replay missed events from the
%%% producer's event store. Position tracked in ETS, persisted to
%%% SQLite on the consumer side.
%%%
%%% Convention: catch-up procedure = `{realm}.replay.{domain}`
%%% @end
%%%-------------------------------------------------------------------
-module(mesh_catch_up).

-include_lib("kernel/include/logger.hrl").

%% Producer API
-export([advertise_replay/3]).

%% Consumer API
-export([catch_up/4, get_position/1, save_position/2]).

%% Internal — position tracking
-export([init_position_table/0]).

-define(POSITION_TABLE, mesh_catch_up_positions).
-define(POSITION_DETS_FILE, "catch_up_positions.dets").
-define(BATCH_SIZE, 500).

%%====================================================================
%% Producer API
%%====================================================================

%% @doc Advertise a catch-up RPC procedure on the mesh.
%% Remote consumers call this to replay events from StoreId.
%%
%% Procedure follows macula_topic convention:
%% {realm}/hecate-social/hecate/{domain}/replay_events_v1
%%
%% The handler reads events in global order from the given offset
%% and returns them as a list.
-spec advertise_replay(binary(), atom(), binary()) -> ok.
advertise_replay(_Realm, StoreId, Domain) ->
    Procedure = hecate_topics:app_hope(Domain, <<"replay_events">>, 1),
    Handler = fun(Args) ->
        Offset = maps:get(<<"since">>, Args, 0),
        Limit = maps:get(<<"limit">>, Args, ?BATCH_SIZE),
        EventTypes = maps:get(<<"event_types">>, Args, undefined),
        replay_from_store(StoreId, Offset, Limit, EventTypes)
    end,
    %% Register intent — applied when mesh activates (local-first boot)
    hecate_mesh:register_advertisement(Procedure, Handler),
    ?LOG_INFO("[catch_up] Registered replay advertisement ~s (store: ~p)", [Procedure, StoreId]),
    ok.

%%====================================================================
%% Consumer API
%%====================================================================

%% @doc Catch up on missed events from a remote producer.
%% Reads from the producer's event store via mesh RPC, starting
%% from the last known position. Calls ProcessFn for each event.
%%
%% ProcessFn = fun(Event :: map()) -> ok
%%
%% Returns the number of events processed, or {error, Reason}.
-spec catch_up(binary(), binary(), binary(), fun((map()) -> ok)) ->
    {ok, non_neg_integer()} | {error, term()}.
catch_up(_Realm, Domain, StreamKey, ProcessFn) ->
    Procedure = hecate_topics:app_hope(Domain, <<"replay_events">>, 1),
    Position = get_position(StreamKey),
    catch_up_loop(Procedure, StreamKey, Position, ProcessFn, 0).

%%====================================================================
%% Position tracking
%%====================================================================

%% @doc Initialize the position table. ETS fronts an optional dets file
%% so positions survive daemon restarts without re-replaying from zero.
%%
%% Resolution:
%%   1. If `shared_paths:run_dir/0' exists (production daemon), open
%%      dets at `{run_dir}/catch_up_positions.dets' and seed ETS.
%%   2. Otherwise (tests, REPL, early boot), run in ETS-only mode — no
%%      persistence but no crash either.
%%
%% Safe to call multiple times; re-opens the existing dets file.
-spec init_position_table() -> ok.
init_position_table() ->
    ensure_ets(),
    ensure_dets(),
    seed_ets_from_dets(),
    ok.

%% @doc Get the last processed position for a stream key.
-spec get_position(binary()) -> non_neg_integer().
get_position(StreamKey) ->
    case ets_whereis() of
        undefined -> 0;
        _ ->
            case ets:lookup(?POSITION_TABLE, StreamKey) of
                [{_, Pos}] -> Pos;
                [] -> 0
            end
    end.

%% @doc Save the last processed position for a stream key. Write-through
%% to dets when the dets file is open; otherwise ETS-only.
-spec save_position(binary(), non_neg_integer()) -> ok.
save_position(StreamKey, Position) ->
    ensure_ets(),
    ets:insert(?POSITION_TABLE, {StreamKey, Position}),
    case dets_open() of
        false -> ok;
        true  ->
            _ = dets:insert(?POSITION_TABLE, {StreamKey, Position}),
            _ = dets:sync(?POSITION_TABLE),
            ok
    end.

%%====================================================================
%% Internal
%%====================================================================

replay_from_store(StoreId, Offset, Limit, undefined) ->
    case reckon_db_streams:read_all_global(StoreId, Offset, Limit) of
        {ok, Events} ->
            Mapped = [event_to_map(E) || E <- Events],
            {ok, #{
                events => Mapped,
                count => length(Mapped),
                offset => Offset,
                has_more => length(Mapped) =:= Limit
            }};
        {error, Reason} ->
            {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
    end;
replay_from_store(StoreId, _Offset, Limit, EventTypes) when is_list(EventTypes) ->
    case reckon_db_streams:read_by_event_types(StoreId, EventTypes, Limit) of
        {ok, Events} ->
            Mapped = [event_to_map(E) || E <- Events],
            {ok, #{
                events => Mapped,
                count => length(Mapped),
                has_more => length(Mapped) =:= Limit
            }};
        {error, Reason} ->
            {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
    end.

catch_up_loop(Procedure, StreamKey, Offset, ProcessFn, TotalProcessed) ->
    case hecate_mesh:call(Procedure, #{<<"since">> => Offset, <<"limit">> => ?BATCH_SIZE}, 30000) of
        {ok, #{<<"events">> := Events, <<"has_more">> := HasMore}} when is_list(Events) ->
            lists:foreach(fun(Event) ->
                ProcessFn(Event)
            end, Events),
            Count = length(Events),
            NewOffset = Offset + Count,
            save_position(StreamKey, NewOffset),
            case HasMore of
                true ->
                    catch_up_loop(Procedure, StreamKey, NewOffset, ProcessFn, TotalProcessed + Count);
                _ ->
                    {ok, TotalProcessed + Count}
            end;
        {ok, #{<<"events">> := []}} ->
            {ok, TotalProcessed};
        {ok, Other} ->
            ?LOG_WARNING("[catch_up] Unexpected response for ~s: ~p", [Procedure, Other]),
            {ok, TotalProcessed};
        {error, Reason} ->
            ?LOG_WARNING("[catch_up] RPC ~s failed: ~p (processed ~b so far)",
                         [Procedure, Reason, TotalProcessed]),
            {error, Reason}
    end.

%% Convert reckon_db event record/map to a clean map for mesh transport
event_to_map(Event) when is_map(Event) ->
    Event;
event_to_map({event, _Id, EventType, StreamId, Version, Data, Metadata, _Tags, _Ts, EpochUs, _, _}) ->
    #{
        event_type => EventType,
        stream_id => StreamId,
        version => Version,
        data => Data,
        metadata => Metadata,
        epoch_us => EpochUs
    };
event_to_map(Other) ->
    ?LOG_WARNING("[catch_up] Unknown event format: ~p", [Other]),
    #{raw => Other}.

%%====================================================================
%% Persistence helpers
%%====================================================================

ensure_ets() ->
    case ets_whereis() of
        undefined ->
            _ = ets:new(?POSITION_TABLE,
                        [named_table, public, set, {read_concurrency, true}]),
            ok;
        _ ->
            ok
    end.

ets_whereis() -> ets:whereis(?POSITION_TABLE).

ensure_dets() ->
    case dets_file_path() of
        undefined -> ok;
        Path ->
            _ = filelib:ensure_dir(Path),
            case dets:info(?POSITION_TABLE) of
                undefined ->
                    case dets:open_file(?POSITION_TABLE,
                                        [{file, Path},
                                         {type, set},
                                         {keypos, 1}]) of
                        {ok, _} -> ok;
                        {error, Reason} ->
                            ?LOG_WARNING("[catch_up] dets open failed ~s: ~p",
                                         [Path, Reason]),
                            ok
                    end;
                _ ->
                    ok
            end
    end.

seed_ets_from_dets() ->
    case dets_open() of
        false -> ok;
        true ->
            Entries = dets:match_object(?POSITION_TABLE, {'_', '_'}),
            lists:foreach(
                fun({K, V}) -> ets:insert(?POSITION_TABLE, {K, V}) end,
                Entries),
            ok
    end.

dets_open() ->
    dets:info(?POSITION_TABLE) =/= undefined.

dets_file_path() ->
    %% shared_paths:run_dir/0 resolves ~/.hecate/hecate-daemon/run in
    %% production; in tests the HECATE_HOME env var may point somewhere
    %% ephemeral. Any failure → ETS-only mode (no persistence).
    try shared_paths:run_dir() of
        Dir when is_list(Dir); is_binary(Dir) ->
            filename:join(Dir, ?POSITION_DETS_FILE)
    catch
        _:_ -> undefined
    end.
