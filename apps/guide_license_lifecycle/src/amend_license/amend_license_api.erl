%%% @doc API handler: PATCH /api/appstore/licenses/:license_id
%%%
%%% Amends any optional fields on a license (before publishing).
%%% Lives in the amend_license desk for vertical slicing.
%%% @end
-module(amend_license_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/:license_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"PATCH">> -> handle_patch(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_patch(Req0, _State) ->
    LicenseId = cowboy_req:binding(license_id, Req0),
    case validate_license_id(LicenseId) of
        ok -> read_body_and_amend(LicenseId, Req0);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req0)
    end.

validate_license_id(undefined) -> {error, <<"license_id is required">>};
validate_license_id(LicenseId) when not is_binary(LicenseId); byte_size(LicenseId) =:= 0 ->
    {error, <<"license_id must be a non-empty string">>};
validate_license_id(_) -> ok.

read_body_and_amend(LicenseId, Req0) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            CmdParams = Params#{<<"license_id">> => LicenseId},
            do_amend(CmdParams, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON body">>, Req1)
    end.

do_amend(Params, Req) ->
    case amend_license_v1:from_map(Params) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_amend_license:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                license_id => amend_license_v1:get_license_id(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
