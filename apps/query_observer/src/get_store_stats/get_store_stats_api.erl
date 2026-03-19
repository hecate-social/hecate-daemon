%%% @doc GET /api/observer/stores/:storeId/stats — Store-level aggregate statistics.
-module(get_store_stats_api).
-export([init/2, routes/0]).

routes() -> [{"/api/observer/stores/:store_id/stats", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    StoreId = binary_to_existing_atom(cowboy_req:binding(store_id, Req0)),
    case evoq_store_inspector:store_stats(StoreId) of
        {ok, Stats} ->
            hecate_api_utils:json_ok(Stats, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, format_error(Reason), Req0)
    end.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> list_to_binary(io_lib:format("~p", [Reason])).
