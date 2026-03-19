%%% @doc GET /api/observer/stores/:storeId/snapshots — List all snapshots in a store.
-module(get_store_snapshots_api).
-export([init/2, routes/0]).

routes() -> [{"/api/observer/stores/:store_id/snapshots", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    StoreId = binary_to_existing_atom(cowboy_req:binding(store_id, Req0)),
    case evoq_store_inspector:list_all_snapshots(StoreId) of
        {ok, Snapshots} ->
            hecate_api_utils:json_ok(#{items => Snapshots, total => length(Snapshots)}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, format_error(Reason), Req0)
    end.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) -> list_to_binary(io_lib:format("~p", [Reason])).
