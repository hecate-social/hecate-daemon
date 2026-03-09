%%% @doc API handler: POST /api/appstore/licenses/revoke
%%%
%%% Revokes a granted license (enforcement action).
%%% Requires license_id. Optional: reason.
%%% @end
-module(revoke_license_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/revoke", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_revoke_license(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_revoke_license(Params, Req) ->
    LicenseId = hecate_api_utils:get_field(license_id, Params),
    case validate(LicenseId) of
        ok -> revoke(Params, LicenseId, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined) -> {error, <<"license_id is required">>};
validate(LicenseId) when not is_binary(LicenseId); byte_size(LicenseId) =:= 0 ->
    {error, <<"license_id must be a non-empty string">>};
validate(_) -> ok.

revoke(Params, LicenseId, Req) ->
    Reason = hecate_api_utils:get_field(reason, Params, undefined),
    CmdParams = #{
        license_id => LicenseId,
        reason => Reason
    },
    case revoke_license_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Err} -> hecate_api_utils:bad_request(Err, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_revoke_license:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                license_id => revoke_license_v1:get_license_id(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
