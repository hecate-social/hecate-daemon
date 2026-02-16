-module(submit_learning_api).
-export([init/2, routes/0]).

routes() -> [{"/api/mentors/learnings/submit", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_submit(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_submit(Params, Req) ->
    CmdParams = #{
        category => maps:get(<<"category">>, Params, undefined),
        domain => maps:get(<<"domain">>, Params, undefined),
        title => maps:get(<<"title">>, Params, undefined),
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
            dispatch_result(maybe_submit_learning:dispatch(Cmd), Cmd, Req);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req)
    end.

dispatch_result({ok, Version, Events}, Cmd, Req) ->
    hecate_api_utils:json_ok(201, #{
        version => Version,
        events => Events,
        learning_id => submit_learning_v1:get_learning_id(Cmd)
    }, Req);
dispatch_result({error, Reason}, _Cmd, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
