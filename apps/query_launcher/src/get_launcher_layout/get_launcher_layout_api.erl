%%% @doc API handler: GET/PUT /api/launcher/layout
%%%
%%% GET  - Returns the full launcher layout.
%%% PUT  - Delegates to reorganize_launcher_api for full layout update.
%%% @end
-module(get_launcher_layout_api).

-export([init/2, routes/0]).

routes() -> [{"/api/launcher/layout", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        <<"PUT">> -> reorganize_launcher_api:handle_put(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_launcher_store:get_layout() of
        {ok, Groups} ->
            hecate_api_utils:json_ok(#{groups => Groups}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
