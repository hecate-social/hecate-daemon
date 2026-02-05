%%% @doc REST handler for mentor/learning management endpoints.
-module(hecate_api_mentors).

-export([init/2]).

%% Learning CRUD
init(Req0, [submit]) ->
    handle_submit(Req0);
init(Req0, [list_learnings]) ->
    handle_list_learnings(Req0);
init(Req0, [get_learning]) ->
    handle_get_learning(Req0);

%% Learning lifecycle
init(Req0, [validate]) ->
    handle_validate(Req0);
init(Req0, [reject]) ->
    handle_reject(Req0);
init(Req0, [endorse]) ->
    handle_endorse(Req0);
init(Req0, [dispute]) ->
    handle_dispute(Req0);
init(Req0, [resolve]) ->
    handle_resolve(Req0);

%% Expertise
init(Req0, [declare]) ->
    handle_declare_expertise(Req0);
init(Req0, [withdraw]) ->
    handle_withdraw_expertise(Req0);

%% Profiles
init(Req0, [list_mentors]) ->
    handle_list_mentors(Req0);
init(Req0, [get_profile]) ->
    handle_get_profile(Req0);

%% Subscriptions
init(Req0, [subscribe]) ->
    handle_subscribe(Req0);
init(Req0, [unsubscribe]) ->
    handle_unsubscribe(Req0);
init(Req0, [list_subs]) ->
    handle_list_subscriptions(Req0);

%% Remote
init(Req0, [list_remote]) ->
    handle_list_remote(Req0).

%% POST /mentors/learnings/submit
handle_submit(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        category => maps:get(<<"category">>, Params),
        domain => maps:get(<<"domain">>, Params),
        title => maps:get(<<"title">>, Params),
        tags => maps:get(<<"tags">>, Params, []),
        description => maps:get(<<"description">>, Params, undefined),
        bad_example => maps:get(<<"bad_example">>, Params, undefined),
        good_example => maps:get(<<"good_example">>, Params, undefined),
        context => maps:get(<<"context">>, Params, undefined),
        severity => maps:get(<<"severity">>, Params, <<"suggestion">>),
        confidence => maps:get(<<"confidence">>, Params, 0.5),
        source => maps:get(<<"source">>, Params, <<"discovered">>)
    },
    case submit_learning_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_submit_learning:dispatch(Cmd) of
                {ok, Version, Events} ->
                    json_response(Req1, 201, #{
                        ok => true,
                        version => Version,
                        events => Events,
                        learning_id => submit_learning_v1:get_learning_id(Cmd)
                    });
                {error, Reason} ->
                    error_response(Req1, 400, Reason)
            end;
        {error, Reason} ->
            error_response(Req1, 400, Reason)
    end.

%% GET /mentors/learnings
handle_list_learnings(Req0) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_learnings:execute(Filters) of
        {ok, Learnings} ->
            json_response(Req0, 200, #{ok => true, learnings => Learnings});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% GET /mentors/learnings/:learning_id
handle_get_learning(Req0) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    case find_learning:execute(LearningId) of
        {ok, Learning} ->
            json_response(Req0, 200, #{ok => true, learning => Learning});
        {error, not_found} ->
            error_response(Req0, 404, <<"not_found">>);
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /mentors/learnings/:learning_id/validate
handle_validate(Req0) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    dispatch_simple_cmd(Req0, validate_learning_v1, maybe_validate_learning, #{learning_id => LearningId}).

%% POST /mentors/learnings/:learning_id/reject
handle_reject(Req0) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = parse_body(Body),
    CmdParams = #{
        learning_id => LearningId,
        reason => maps:get(<<"reason">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, reject_learning_v1, maybe_reject_learning, CmdParams).

%% POST /mentors/learnings/:learning_id/endorse
handle_endorse(Req0) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    dispatch_simple_cmd(Req0, endorse_learning_v1, maybe_endorse_learning, #{learning_id => LearningId}).

%% POST /mentors/learnings/:learning_id/dispute
handle_dispute(Req0) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = parse_body(Body),
    CmdParams = #{
        learning_id => LearningId,
        reason => maps:get(<<"reason">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, dispute_learning_v1, maybe_dispute_learning, CmdParams).

%% POST /mentors/learnings/:learning_id/resolve
handle_resolve(Req0) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = parse_body(Body),
    CmdParams = #{
        learning_id => LearningId,
        resolution => maps:get(<<"resolution">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, resolve_learning_dispute_v1, maybe_resolve_learning_dispute, CmdParams).

%% POST /mentors/expertise
handle_declare_expertise(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        domains => maps:get(<<"domains">>, Params, [])
    },
    dispatch_simple_cmd(Req1, declare_expertise_v1, maybe_declare_expertise, CmdParams).

%% DELETE /mentors/expertise/withdraw
handle_withdraw_expertise(Req0) ->
    dispatch_simple_cmd(Req0, withdraw_expertise_v1, maybe_withdraw_expertise, #{}).

%% GET /mentors/profiles
handle_list_mentors(Req0) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = case proplists:get_value(<<"domain">>, QS) of
        undefined -> #{};
        Domain -> #{domain => Domain}
    end,
    case list_mentors:execute(Filters) of
        {ok, Mentors} ->
            json_response(Req0, 200, #{ok => true, mentors => Mentors});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% GET /mentors/profiles/:agent_id
handle_get_profile(Req0) ->
    AgentId = cowboy_req:binding(agent_id, Req0),
    case get_mentor_profile:execute(AgentId) of
        {ok, Profile} ->
            json_response(Req0, 200, #{ok => true, profile => Profile});
        {error, not_found} ->
            error_response(Req0, 404, <<"not_found">>);
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /mentors/subscribe
handle_subscribe(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        mentor_id => maps:get(<<"mentor_id">>, Params)
    },
    dispatch_simple_cmd(Req1, subscribe_to_mentor_v1, maybe_subscribe_to_mentor, CmdParams).

%% POST /mentors/unsubscribe
handle_unsubscribe(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        mentor_id => maps:get(<<"mentor_id">>, Params)
    },
    dispatch_simple_cmd(Req1, unsubscribe_from_mentor_v1, maybe_unsubscribe_from_mentor, CmdParams).

%% GET /mentors/subscriptions
handle_list_subscriptions(Req0) ->
    SubscriberId = hecate_identity:agent_id(),
    case list_subscriptions:execute(SubscriberId) of
        {ok, Subs} ->
            json_response(Req0, 200, #{ok => true, subscriptions => Subs});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% GET /mentors/remote
handle_list_remote(Req0) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_remote_learnings:execute(Filters) of
        {ok, Remote} ->
            json_response(Req0, 200, #{ok => true, remote_learnings => Remote});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% Internal helpers

dispatch_simple_cmd(Req, CmdMod, HandlerMod, CmdParams) ->
    case CmdMod:new(CmdParams) of
        {ok, Cmd} ->
            case HandlerMod:dispatch(Cmd) of
                {ok, Version, Events} ->
                    json_response(Req, 200, #{
                        ok => true,
                        version => Version,
                        events => Events
                    });
                {error, Reason} ->
                    error_response(Req, 400, Reason)
            end;
        {error, Reason} ->
            error_response(Req, 400, Reason)
    end.

build_filters(QS) ->
    lists:foldl(fun({K, V}, Acc) ->
        case K of
            <<"domain">> -> Acc#{domain => V};
            <<"category">> -> Acc#{category => V};
            <<"status">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{status_mask => I};
                    _ -> Acc
                end;
            <<"limit">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{limit => I};
                    _ -> Acc
                end;
            <<"offset">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{offset => I};
                    _ -> Acc
                end;
            _ -> Acc
        end
    end, #{}, QS).

parse_body(<<>>) -> #{};
parse_body(Body) -> json:decode(Body).

json_response(Req, StatusCode, Data) ->
    Response = json:encode(Data),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req),
    {ok, Req2, []}.

error_response(Req, StatusCode, Reason) when is_atom(Reason) ->
    error_response(Req, StatusCode, atom_to_binary(Reason, utf8));
error_response(Req, StatusCode, Reason) ->
    Response = json:encode(#{ok => false, error => Reason}),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req),
    {ok, Req2, []}.
