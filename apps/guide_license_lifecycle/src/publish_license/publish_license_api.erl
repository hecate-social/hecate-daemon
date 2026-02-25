%%% @doc API handler: POST /api/appstore/licenses/:license_id/publish
%%%
%%% Publishes a license, making it available for purchase.
%%% Lives in the publish_license desk for vertical slicing.
%%% @end
-module(publish_license_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/:license_id/publish", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    LicenseId = cowboy_req:binding(license_id, Req0),
    case validate(LicenseId) of
        ok -> do_publish(LicenseId, Req0);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req0)
    end.

validate(undefined) -> {error, <<"license_id is required">>};
validate(LicenseId) when not is_binary(LicenseId); byte_size(LicenseId) =:= 0 ->
    {error, <<"license_id must be a non-empty string">>};
validate(_) -> ok.

do_publish(LicenseId, Req) ->
    case publish_license_v1:new(#{license_id => LicenseId}) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_publish_license:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                license_id => publish_license_v1:get_license_id(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
