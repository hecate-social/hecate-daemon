%%% @doc API handler: GET /api/appstore/offerings
%%%
%%% Returns the full offerings catalog (public, no auth required).
%%% Only shows published offerings available for licensing.
%%% @end
-module(browse_offerings_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/offerings", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_license_offerings_store:browse_offerings() of
        {ok, Items} ->
            hecate_api_utils:json_ok(#{items => Items}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
