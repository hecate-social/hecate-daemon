-module(hecate_api_identities).

-export([init/2]).

init(Req0, [list]) -> handle_list(Req0);
init(Req0, [register]) -> handle_register(Req0);
init(Req0, [get]) -> handle_get(Req0);
init(Req0, [update]) -> handle_update(Req0).

%% GET /agents
handle_list(Req0) ->
    QsVals = cowboy_req:parse_qs(Req0),
    Limit = parse_int(proplists:get_value(<<"limit">>, QsVals), 100),
    Offset = parse_int(proplists:get_value(<<"offset">>, QsVals), 0),
    list_result(list_identities:execute(#{limit => Limit, offset => Offset}), Limit, Offset, Req0).

list_result({ok, Identities}, Limit, Offset, Req) ->
    Response = json:encode(#{
        ok => true,
        agents => Identities,
        count => length(Identities),
        limit => Limit,
        offset => Offset
    }),
    reply(200, Response, Req);
list_result({error, Reason}, _, _, Req) ->
    error_response(Req, 500, Reason).

%% POST /agents/register
handle_register(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_register(Decoded, Req1).

do_register(#{<<"mri">> := MRI, <<"public_key">> := PubKey, <<"key_type">> := KeyType} = P, Req) ->
    Metadata = maps:get(<<"metadata">>, P, #{}),
    Timestamp = erlang:system_time(millisecond),
    Cmd = register_identity_v1:new(MRI, PubKey, KeyType, Metadata, Timestamp),
    dispatch_result(maybe_register_identity:dispatch(Cmd), 201, Req);
do_register(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% GET /agents/:agent_identity
handle_get(Req0) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    get_result(find_identity:execute(AgentIdentity), Req0).

get_result({ok, Identity}, Req) ->
    Response = json:encode(#{ok => true, agent => Identity}),
    reply(200, Response, Req);
get_result({error, not_found}, Req) ->
    error_response(Req, 404, identity_not_found);
get_result({error, Reason}, Req) ->
    error_response(Req, 500, Reason).

%% POST /agents/:agent_identity/update
handle_update(Req0) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_update(AgentIdentity, Decoded, Req1).

do_update(AgentIdentity, #{<<"metadata">> := Metadata}, Req) ->
    Timestamp = erlang:system_time(millisecond),
    Cmd = update_identity_v1:new(AgentIdentity, Metadata, Timestamp),
    dispatch_result(maybe_update_identity:dispatch(Cmd), 200, Req);
do_update(_, _, Req) ->
    error_response(Req, 400, invalid_request_body).

%% Internal helpers

parse_int(undefined, Default) -> Default;
parse_int(Bin, _Default) -> binary_to_integer(Bin).

dispatch_result({ok, Version, Events}, Status, Req) ->
    Response = json:encode(#{ok => true, version => Version, events => Events}),
    reply(Status, Response, Req);
dispatch_result({error, Reason}, _, Req) ->
    error_response(Req, 400, Reason).

reply(Status, Response, Req) ->
    Req2 = cowboy_req:reply(Status, #{<<"content-type">> => <<"application/json">>}, Response, Req),
    {ok, Req2, []}.

error_response(Req, StatusCode, Reason) when is_atom(Reason) ->
    Response = json:encode(#{ok => false, error => atom_to_binary(Reason, utf8)}),
    reply(StatusCode, Response, Req);
error_response(Req, StatusCode, Reason) when is_binary(Reason) ->
    Response = json:encode(#{ok => false, error => Reason}),
    reply(StatusCode, Response, Req).
