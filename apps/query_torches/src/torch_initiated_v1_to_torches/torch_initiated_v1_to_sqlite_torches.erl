%%% @doc Projection: torch_initiated_v1 -> sqlite torches table
%%% Inserts/updates torch records in the SQLite read model.
-module(torch_initiated_v1_to_sqlite_torches).

-include_lib("manage_torches/include/torch_status.hrl").

-export([project/1]).

%% @doc Project torch_initiated_v1 event to torches table.
%% Computes and stores status_label at write time.
-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    TorchId = get(torch_id, Event),
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, TorchId]),
    Status = evoq_bit_flags:set_all(0, [?TORCH_INITIATED, ?TORCH_DNA_ACTIVE]),
    StatusLabel = evoq_bit_flags:to_string(Status, ?TORCH_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO torches "
          "(torch_id, name, brief, status, status_label, repos, skills, context_map, "
          "active_cartwheel_id, initiated_at, initiated_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
    Result = query_torches_store:execute(Sql, [
        TorchId,
        get(name, Event, <<>>),
        get(brief, Event),
        Status,
        StatusLabel,
        encode_json(get(repos, Event)),
        encode_json(get(skills, Event)),
        encode_json(get(context_map, Event)),
        undefined,  %% No active cartwheel yet
        get(initiated_at, Event, erlang:system_time(millisecond)),
        get(initiated_by, Event)
    ]),
    logger:info("[PROJECTION] ~s: result = ~p", [?MODULE, Result]),
    Result.

%% Internal

-spec encode_json(term()) -> binary() | undefined.
encode_json(undefined) -> undefined;
encode_json(Term) -> json:encode(Term).

%% @doc Get value from event map, handling both atom and binary keys.
-spec get(atom(), map()) -> term().
get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.

-spec get(atom(), map(), term()) -> term().
get(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
