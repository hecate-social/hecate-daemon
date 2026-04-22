%%% @doc API handler: POST /api/realms/:membership_id/resign
%%%
%%% Replaces the previous `/api/realms/:id/leave` endpoint. The verb
%%% "resign" reflects that this is member-initiated — admin-revoke
%%% comes from the mesh via `listen_for_membership_revoked` and does
%%% not have a daemon-local HTTP entry point.
%%% @end
-module(resign_realm_membership_api).
-export([init/2, routes/0]).

-dialyzer({nowarn_function, [handle_post/2]}).

routes() -> [{"/api/realms/:membership_id/resign", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    MembershipId = cowboy_req:binding(membership_id, Req0),
    Now = erlang:system_time(millisecond),
    case resign_realm_membership_v1:new(#{membership_id => MembershipId,
                                           resigned_at   => Now}) of
        {ok, Cmd} ->
            case maybe_resign_realm_membership:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    hecate_api_utils:json_ok(
                        #{resigned => true, membership_id => MembershipId}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
