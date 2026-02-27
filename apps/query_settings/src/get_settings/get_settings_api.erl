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
    Sql = "SELECT linux_user, hostname, hecate_user_id,
                  preferences, status, initiated_at
           FROM settings WHERE id = 1",
    case project_settings_store:query(Sql) of
        {ok, [[LinuxUser, Hostname, HecateUserId,
               PrefsJson, Status, InitiatedAt]]} ->
            Prefs = try json:decode(PrefsJson) catch _:_ -> #{} end,
            Identity = #{
                hecate_user_id => HecateUserId,
                linux_user => LinuxUser,
                hostname => Hostname,
                initiated_at => InitiatedAt,
                status => Status
            },
            Realms = fetch_realms(),
            hecate_api_utils:json_ok(#{
                identity => Identity,
                preferences => Prefs,
                realms => Realms
            }, Req0);
        {ok, []} ->
            hecate_api_utils:json_error(404, <<"Settings not initialized">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

fetch_realms() ->
    Sql = "SELECT membership_id, realm_id, realm_url, oauth_account, oauth_provider, confirmed_at
           FROM realm_memberships WHERE status = 'confirmed' ORDER BY confirmed_at",
    case project_realm_memberships_store:query(Sql) of
        {ok, Rows} ->
            lists:map(fun([MId, RId, RUrl, Acct, Prov, At]) ->
                #{membership_id => MId, realm_id => RId, realm_url => RUrl,
                  oauth_account => Acct, oauth_provider => Prov, confirmed_at => At}
            end, Rows);
        _ ->
            []
    end.
