%%% @doc API handler: GET /api/settings
-module(get_settings_api).
-export([init/2, routes/0]).

routes() -> [{"/api/settings", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Sql = "SELECT linux_user, hostname, github_user, hecate_user_id, realm,
                  paired, paired_at, preferences, status, initiated_at
           FROM settings WHERE id = 1",
    case project_settings_store:query(Sql) of
        {ok, [[LinuxUser, Hostname, GithubUser, HecateUserId, Realm,
               Paired, PairedAt, PrefsJson, Status, InitiatedAt]]} ->
            Prefs = try json:decode(PrefsJson) catch _:_ -> #{} end,
            Identity = #{
                hecate_user_id => HecateUserId,
                linux_user => LinuxUser,
                hostname => Hostname,
                github_user => GithubUser,
                realm => Realm,
                paired => Paired =:= 1,
                paired_at => PairedAt,
                initiated_at => InitiatedAt,
                status => Status
            },
            hecate_api_utils:json_ok(#{identity => Identity, preferences => Prefs}, Req0);
        {ok, []} ->
            hecate_api_utils:json_error(404, <<"Settings not initialized">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
