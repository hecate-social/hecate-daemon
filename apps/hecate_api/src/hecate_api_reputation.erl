-module(hecate_api_reputation).

-export([init/2]).

init(Req0, [get]) ->
    handle_get_reputation(Req0);
init(Req0, [list_calls]) ->
    handle_list_calls(Req0);
init(Req0, [list_disputes]) ->
    handle_list_disputes(Req0).

%% GET /reputation/:agent_identity
handle_get_reputation(Req0) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),

    Query = get_reputation_v1:new(AgentIdentity),

    case handle_get_reputation:handle(Query) of
        {ok, Reputation} ->
            Response = json:encode(#{
                ok => true,
                reputation => Reputation
            }),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, []};
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% GET /rpc-calls?agent_identity=...&success=...&limit=...
handle_list_calls(Req0) ->
    QsVals = cowboy_req:parse_qs(Req0),
    AgentIdentity = proplists:get_value(<<"agent_identity">>, QsVals),
    SuccessFilter = case proplists:get_value(<<"success">>, QsVals) of
        <<"true">> -> true;
        <<"false">> -> false;
        _ -> undefined
    end,
    Limit = binary_to_integer(proplists:get_value(<<"limit">>, QsVals, <<"50">>)),

    Query = list_rpc_calls_v1:new(AgentIdentity, Limit, SuccessFilter),

    case handle_list_rpc_calls:handle(Query) of
        {ok, Calls} ->
            Response = json:encode(#{
                ok => true,
                calls => Calls,
                count => length(Calls)
            }),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, []};
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% GET /disputes?agent_identity=...&status=...
handle_list_disputes(Req0) ->
    QsVals = cowboy_req:parse_qs(Req0),
    AgentIdentity = proplists:get_value(<<"agent_identity">>, QsVals, undefined),
    StatusFilter = proplists:get_value(<<"status">>, QsVals, undefined),

    Query = list_disputes_v1:new(AgentIdentity, StatusFilter),

    case handle_list_disputes:handle(Query) of
        {ok, Disputes} ->
            Response = json:encode(#{
                ok => true,
                disputes => Disputes,
                count => length(Disputes)
            }),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, []};
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% Internal functions

error_response(Req, StatusCode, Reason) ->
    ErrorBin = format_error(Reason),
    Response = json:encode(#{
        ok => false,
        error => ErrorBin
    }),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response,
        Req
    ),
    {ok, Req2, []}.

%% esqlite3 returns integer error codes
format_error(_Reason) ->
    <<"database_error">>.
