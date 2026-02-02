-module(hecate_api_subscriptions).

-export([init/2]).

init(Req0, [list]) -> handle_list(Req0);
init(Req0, [subscribe]) -> handle_subscribe(Req0);
init(Req0, [unsubscribe]) -> handle_unsubscribe(Req0);
init(Req0, [stats]) -> handle_stats(Req0).

%% GET /subscriptions?agent_identity=...
handle_list(Req0) ->
    QsVals = cowboy_req:parse_qs(Req0),
    AgentIdentity = proplists:get_value(<<"agent_identity">>, QsVals),
    do_list(AgentIdentity, Req0).

do_list(undefined, Req) ->
    error_response(Req, 400, agent_identity_required);
do_list(AgentIdentity, Req) ->
    query_result(get_subscriptions:execute(AgentIdentity), subscriptions, Req).

%% POST /subscriptions/subscribe
handle_subscribe(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_subscribe(Decoded, Req1).

do_subscribe(#{<<"agent_identity">> := Agent, <<"topic">> := Topic} = Payload, Req) ->
    Filter = maps:get(<<"filter">>, Payload, undefined),
    Timestamp = erlang:system_time(millisecond),
    Cmd = subscribe_v1:new(Agent, Topic, Filter, Timestamp),
    dispatch_result(maybe_subscribe:dispatch(Cmd), 201, Req);
do_subscribe(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% POST /subscriptions/unsubscribe
handle_unsubscribe(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_unsubscribe(Decoded, Req1).

do_unsubscribe(#{<<"agent_identity">> := Agent, <<"topic">> := Topic}, Req) ->
    Timestamp = erlang:system_time(millisecond),
    Cmd = unsubscribe_v1:new(Agent, Topic, Timestamp),
    dispatch_result(maybe_unsubscribe:dispatch(Cmd), 200, Req);
do_unsubscribe(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% GET /subscriptions/stats?agent_identity=...
handle_stats(Req0) ->
    QsVals = cowboy_req:parse_qs(Req0),
    AgentIdentity = proplists:get_value(<<"agent_identity">>, QsVals),
    do_stats(AgentIdentity, Req0).

do_stats(undefined, Req) ->
    error_response(Req, 400, agent_identity_required);
do_stats(AgentIdentity, Req) ->
    stats_result(get_subscription_stats:for_agent(AgentIdentity), Req).

stats_result({ok, Stats}, Req) ->
    Response = json:encode(#{ok => true, stats => Stats}),
    reply(200, Response, Req);
stats_result({error, Reason}, Req) ->
    error_response(Req, 500, Reason).

%% Internal helpers

dispatch_result({ok, Version, Events}, Status, Req) ->
    Response = json:encode(#{ok => true, version => Version, events => Events}),
    reply(Status, Response, Req);
dispatch_result({error, Reason}, _, Req) ->
    error_response(Req, 400, Reason).

query_result({ok, Items}, Key, Req) ->
    Response = json:encode(#{ok => true, Key => Items, count => length(Items)}),
    reply(200, Response, Req);
query_result({error, Reason}, _, Req) ->
    error_response(Req, 500, Reason).

reply(Status, Response, Req) ->
    Req2 = cowboy_req:reply(Status, #{<<"content-type">> => <<"application/json">>}, Response, Req),
    {ok, Req2, []}.

error_response(Req, StatusCode, Reason) ->
    Response = json:encode(#{ok => false, error => atom_to_binary(Reason, utf8)}),
    reply(StatusCode, Response, Req).
