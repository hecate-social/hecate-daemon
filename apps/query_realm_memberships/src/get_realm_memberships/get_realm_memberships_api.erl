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
    Sql = "SELECT membership_id, realm_id, realm_url, oauth_account, oauth_provider, confirmed_at
           FROM realm_memberships WHERE status = 'confirmed' ORDER BY confirmed_at",
    case project_realm_memberships_store:query(Sql) of
        {ok, Rows} ->
            Memberships = lists:map(fun row_to_map/1, Rows),
            hecate_api_utils:json_ok(#{realms => Memberships}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

row_to_map({MembershipId, RealmId, RealmUrl, OAuthAccount, OAuthProvider, ConfirmedAt}) ->
    #{
        membership_id => MembershipId,
        realm_id => RealmId,
        realm_url => RealmUrl,
        oauth_account => OAuthAccount,
        oauth_provider => OAuthProvider,
        confirmed_at => ConfirmedAt
    }.
