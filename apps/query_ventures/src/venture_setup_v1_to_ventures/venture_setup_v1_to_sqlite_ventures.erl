%%% @doc Projection: venture_setup_v1 -> sqlite ventures table
-module(venture_setup_v1_to_sqlite_ventures).

-include_lib("setup_venture/include/venture_status.hrl").

-export([project/1]).

%% @doc Project venture_setup_v1 event to ventures table.
-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    VentureId = get(venture_id, Event),
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, VentureId]),
    Status = evoq_bit_flags:set(0, ?VENTURE_SETUP),
    StatusLabel = evoq_bit_flags:to_string(Status, ?VENTURE_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO ventures "
          "(venture_id, name, brief, status, status_label, repos, skills, context_map, "
          "initiated_at, initiated_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
    Result = query_ventures_store:execute(Sql, [
        VentureId,
        get(name, Event, <<>>),
        get(brief, Event),
        Status,
        StatusLabel,
        encode_json(get(repos, Event)),
        encode_json(get(skills, Event)),
        encode_json(get(context_map, Event)),
        get(initiated_at, Event, erlang:system_time(millisecond)),
        get(initiated_by, Event)
    ]),
    logger:info("[PROJECTION] ~s: result = ~p", [?MODULE, Result]),
    Result.

%% Internal

-spec encode_json(term()) -> binary() | undefined.
encode_json(undefined) -> undefined;
encode_json(Term) -> json:encode(Term).

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
