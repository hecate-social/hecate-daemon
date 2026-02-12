%%% @doc API handler: GET /api/venture
%%% Returns the first non-archived venture (the "active" venture).
-module(get_active_venture_api).

-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    %% Find first venture where ARCHIVED bit is NOT set
    Sql = "SELECT venture_id, name, brief, status, status_label, "
          "repos, skills, context_map, initiated_at, initiated_by "
          "FROM ventures WHERE (status & ?1) = 0 "
          "ORDER BY initiated_at DESC LIMIT 1",
    case query_venture_lifecycle_store:query(Sql, [?VL_ARCHIVED]) of
        {ok, [Row]} ->
            hecate_api_utils:json_ok(#{venture => row_to_map(Row)}, Req0);
        {ok, []} ->
            hecate_api_utils:json_error(404, <<"No active venture">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

row_to_map({VentureId, Name, Brief, Status, StatusLabel,
            Repos, Skills, ContextMap, InitiatedAt, InitiatedBy}) ->
    #{
        venture_id => VentureId,
        name => Name,
        brief => Brief,
        status => Status,
        status_label => StatusLabel,
        repos => decode_json(Repos),
        skills => decode_json(Skills),
        context_map => decode_json(ContextMap),
        initiated_at => InitiatedAt,
        initiated_by => InitiatedBy
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).

decode_json(null) -> null;
decode_json(undefined) -> null;
decode_json(Val) when is_binary(Val) -> json:decode(Val);
decode_json(Val) -> Val.
