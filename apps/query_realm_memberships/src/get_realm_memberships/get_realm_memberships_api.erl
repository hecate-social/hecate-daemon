%%% @doc API handler: GET /api/realms
%%%
%%% Returns active (confirmed, not revoked) realm memberships.
-module(get_realm_memberships_api).
-export([init/2, routes/0]).

routes() -> [{"/api/realms", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_realm_memberships_store:list_confirmed() of
        {ok, Memberships} ->
            hecate_api_utils:json_ok(#{realms => Memberships}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
