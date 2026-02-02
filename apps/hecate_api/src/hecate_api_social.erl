-module(hecate_api_social).

-export([init/2]).

init(Req0, [follow]) -> handle_follow(Req0);
init(Req0, [unfollow]) -> handle_unfollow(Req0);
init(Req0, [endorse]) -> handle_endorse(Req0);
init(Req0, [revoke_endorsement]) -> handle_revoke_endorsement(Req0);
init(Req0, [get_followers]) -> handle_get_followers(Req0);
init(Req0, [get_following]) -> handle_get_following(Req0);
init(Req0, [get_endorsements]) -> handle_get_endorsements(Req0);
init(Req0, [get_social_graph]) -> handle_get_social_graph(Req0).

%% POST /social/follow
handle_follow(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_follow(Decoded, Req1).

do_follow(#{<<"follower_identity">> := Follower, <<"followed_identity">> := Followed}, Req) ->
    Cmd = follow_agent_v1:new(Follower, Followed),
    dispatch_result(maybe_follow_agent:dispatch(Cmd), 201, Req);
do_follow(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% POST /social/unfollow
handle_unfollow(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_unfollow(Decoded, Req1).

do_unfollow(#{<<"follower_identity">> := Follower, <<"followed_identity">> := Followed}, Req) ->
    Cmd = unfollow_agent_v1:new(Follower, Followed),
    dispatch_result(maybe_unfollow_agent:dispatch(Cmd), 200, Req);
do_unfollow(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% POST /social/endorse
handle_endorse(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_endorse(Decoded, Req1).

do_endorse(#{<<"endorser_identity">> := Endorser, <<"capability_mri">> := Mri} = P, Req) ->
    Comment = maps:get(<<"comment">>, P, undefined),
    Cmd = endorse_capability_v1:new(Endorser, Mri, Comment),
    dispatch_result(maybe_endorse_capability:dispatch(Cmd), 201, Req);
do_endorse(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% POST /social/endorsement/revoke
handle_revoke_endorsement(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_revoke_endorsement(Decoded, Req1).

do_revoke_endorsement(#{<<"endorser_identity">> := Endorser, <<"capability_mri">> := Mri}, Req) ->
    Cmd = revoke_endorsement_v1:new(Endorser, Mri),
    dispatch_result(maybe_revoke_endorsement:dispatch(Cmd), 200, Req);
do_revoke_endorsement(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% GET /social/followers/:agent_identity
handle_get_followers(Req0) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    query_result(get_followers:execute(AgentIdentity), followers, Req0).

%% GET /social/following/:agent_identity
handle_get_following(Req0) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    query_result(get_following:execute(AgentIdentity), following, Req0).

%% GET /social/endorsements/:agent_identity
handle_get_endorsements(Req0) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    QsVals = cowboy_req:parse_qs(Req0),
    QueryType = proplists:get_value(<<"type">>, QsVals, <<"given">>),
    Result = endorsements_query(QueryType, AgentIdentity),
    endorsements_result(Result, QueryType, Req0).

endorsements_query(<<"given">>, Agent) -> get_endorsements:by_endorser(Agent);
endorsements_query(<<"received">>, Agent) -> get_endorsements:by_capability_owner(Agent);
endorsements_query(_, Agent) -> get_endorsements:by_endorser(Agent).

endorsements_result({ok, Endorsements}, QueryType, Req) ->
    Response = json:encode(#{
        ok => true,
        endorsements => Endorsements,
        count => length(Endorsements),
        type => QueryType
    }),
    reply(200, Response, Req);
endorsements_result({error, Reason}, _, Req) ->
    error_response(Req, 500, Reason).

%% GET /social/graph/:agent_identity
handle_get_social_graph(Req0) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    QsVals = cowboy_req:parse_qs(Req0),
    Limit = parse_int(proplists:get_value(<<"limit">>, QsVals), 100),

    Opts = #{limit_per_section => Limit},

    %% get_social_graph:execute/2 always succeeds (errors handled internally)
    {ok, Graph} = get_social_graph:execute(AgentIdentity, Opts),
    Response = json:encode(#{ok => true, graph => Graph}),
    reply(200, Response, Req0).

parse_int(undefined, Default) -> Default;
parse_int(Bin, _Default) -> binary_to_integer(Bin).

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

error_response(Req, StatusCode, Reason) when is_atom(Reason) ->
    Response = json:encode(#{ok => false, error => atom_to_binary(Reason, utf8)}),
    reply(StatusCode, Response, Req);
error_response(Req, StatusCode, Reason) when is_binary(Reason) ->
    Response = json:encode(#{ok => false, error => Reason}),
    reply(StatusCode, Response, Req).
