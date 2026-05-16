%%% @doc GET /api/mesh/activity[?since=<ms>&limit=<n>]
%%%
%%% Returns recent agent activity (publications + artifact shares) from
%%% the `mesh_activity' ETS read model, in chronological order.
%%%
%%% Query params:
%%%   since   integer ms epoch (default 0)
%%%   limit   pos int       (default 200, max 2000)
%%%
%%% Response:
%%%   #{ok => true,
%%%     events => [
%%%        #{fact_id => <<...>>, kind => <<...>>, ts_ms => N, payload => #{...}},
%%%        ...
%%%     ]}
%%%
%%% v1 surfaces ONLY this daemon's own publish/share activity. External
%%% FACT subscription via LISTENER lands when realm-scoped activity
%%% topic conventions are agreed (see PLAN_MACULA_MCP.md).
%%% @end
-module(get_mesh_activity_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/activity", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Qs    = cowboy_req:parse_qs(Req0),
    Since = parse_int(proplists:get_value(<<"since">>, Qs), 0),
    Limit = parse_int(proplists:get_value(<<"limit">>, Qs), 200),
    {ok, Events} = project_mesh_activity_store:since(Since, Limit),
    hecate_api_utils:json_ok(#{events => Events}, Req0).

parse_int(undefined, Default) -> Default;
parse_int(Bin, Default) when is_binary(Bin) ->
    try binary_to_integer(Bin) of
        N when is_integer(N) -> N
    catch
        _:_ -> Default
    end;
parse_int(_, Default) -> Default.
