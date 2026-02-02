%%%-------------------------------------------------------------------
%%% @doc Pairing API endpoint.
%%%
%%% Provides HTTP endpoints for device pairing:
%%% - POST /api/pairing/start  - Start pairing session
%%% - GET  /api/pairing/status - Get pairing status
%%% - POST /api/pairing/cancel - Cancel active pairing
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_pairing).

-export([init/2]).

init(Req0, [Action]) ->
    Method = cowboy_req:method(Req0),
    handle(Method, Action, Req0).

%% POST /api/pairing/start
handle(<<"POST">>, start, Req0) ->
    Response = case hecate_pairing:start_pairing() of
        {ok, SessionData} ->
            #{
                ok => true,
                session_id => maps:get(session_id, SessionData),
                confirm_code => maps:get(confirm_code, SessionData),
                pairing_url => maps:get(pairing_url, SessionData),
                expires_in => maps:get(expires_in, SessionData, 600)
            };
        {error, identity_not_initialized} ->
            #{
                ok => false,
                error => <<"identity_not_initialized">>,
                hint => <<"Run 'hecate init' to create identity first">>
            };
        {error, Reason} ->
            #{
                ok => false,
                error => format_error(Reason)
            }
    end,
    reply_json(Response, Req0);

%% GET /api/pairing/status
handle(<<"GET">>, status, Req0) ->
    Status = hecate_pairing:get_status(),
    Response = #{
        ok => true,
        status => maps:get(status, Status),
        session_id => maps:get(session_id, Status, null),
        confirm_code => maps:get(confirm_code, Status, null),
        pairing_url => maps:get(pairing_url, Status, null),
        expires_in => maps:get(expires_in, Status, null)
    },
    reply_json(Response, Req0);

%% POST /api/pairing/cancel
handle(<<"POST">>, cancel, Req0) ->
    ok = hecate_pairing:cancel(),
    Response = #{ok => true, status => <<"cancelled">>},
    reply_json(Response, Req0);

%% Method not allowed
handle(_Method, _Action, Req0) ->
    Response = #{ok => false, error => <<"method_not_allowed">>},
    reply_json(405, Response, Req0).

%% Internal functions

reply_json(Response, Req0) ->
    reply_json(200, Response, Req0).

reply_json(StatusCode, Response, Req0) ->
    Body = json:encode(Response),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, []}.

format_error({http_error, Code}) ->
    iolist_to_binary(io_lib:format("http_error_~p", [Code]));
format_error(Reason) when is_atom(Reason) ->
    atom_to_binary(Reason);
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
