%%% @doc API handler: GET /api/settings
%%%
%%% Returns identity + preferences + realm memberships.
-module(get_settings_api).
-export([init/2, routes/0]).

routes() -> [{"/api/settings", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_settings_store:get() of
        {ok, #{hecate_user_id := HecateUserId, linux_user := LinuxUser,
               hostname := Hostname, preferences := Prefs,
               status := Status, initiated_at := InitiatedAt}} ->
            Identity = #{
                hecate_user_id => HecateUserId,
                linux_user => LinuxUser,
                hostname => Hostname,
                initiated_at => InitiatedAt,
                status => Status
            },
            {ok, Realms} = project_realm_memberships_store:list_confirmed(),
            hecate_api_utils:json_ok(#{
                identity => Identity,
                preferences => Prefs,
                realms => Realms
            }, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Settings not initialized">>, Req0)
    end.
