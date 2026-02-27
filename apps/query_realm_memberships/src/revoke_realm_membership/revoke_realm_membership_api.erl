%%% @doc API handler: POST /api/realms/:membership_id/leave
%%%
%%% Dispatches revoke_realm_membership_v1 to leave a realm.
-module(revoke_realm_membership_api).
-export([init/2, routes/0]).

-dialyzer({nowarn_function, [handle_post/2]}).

routes() -> [{"/api/realms/:membership_id/leave", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    MembershipId = cowboy_req:binding(membership_id, Req0),
    Now = erlang:system_time(millisecond),
    Cmd = revoke_realm_membership_v1:new(MembershipId, <<"manual">>, Now),
    case maybe_revoke_realm_membership:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{revoked => true, membership_id => MembershipId}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
