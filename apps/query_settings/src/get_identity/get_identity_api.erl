%%% @doc API handler: GET /api/settings/identity
-module(get_identity_api).
-export([init/2, routes/0]).

routes() -> [{"/api/settings/identity", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Sql = "SELECT hecate_user_id, linux_user, hostname
           FROM settings WHERE id = 1",
    case project_settings_store:query(Sql) of
        {ok, [{HecateUserId, LinuxUser, Hostname}]} ->
            Identity = #{
                hecate_user_id => HecateUserId,
                linux_user => LinuxUser,
                hostname => Hostname
            },
            hecate_api_utils:json_ok(#{identity => Identity}, Req0);
        {ok, []} ->
            hecate_api_utils:json_error(404, <<"Settings not initialized">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
