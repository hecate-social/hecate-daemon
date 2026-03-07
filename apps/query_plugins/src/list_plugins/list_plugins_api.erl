%%% @doc API handler: GET /api/appstore/plugins
%%%
%%% Returns all installed (non-removed) plugins on this node.
%%% @end
-module(list_plugins_api).

-export([init/2, routes/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

routes() -> [{"/api/appstore/plugins", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_plugins_store:list_active() of
        {ok, Plugins} ->
            hecate_api_utils:json_ok(#{items => Plugins}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
