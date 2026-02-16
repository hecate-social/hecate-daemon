-module(register_identity_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/identity/register", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"mri">> := MRI, <<"public_key">> := PubKey, <<"key_type">> := KeyType} = P, Req1} ->
            Metadata = maps:get(<<"metadata">>, P, #{}),
            Timestamp = erlang:system_time(millisecond),
            Cmd = register_identity_v1:new(MRI, PubKey, KeyType, Metadata, Timestamp),
            dispatch_result(maybe_register_identity:dispatch(Cmd), Req1);
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"Missing mri, public_key, or key_type">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(201, #{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
