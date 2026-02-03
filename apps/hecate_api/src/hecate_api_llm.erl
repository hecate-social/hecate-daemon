%%% @doc LLM API endpoints.
%%%
%%% Provides REST interface to local LLM inference:
%%% - GET  /api/llm/models  - List available models
%%% - POST /api/llm/chat    - Chat completion (supports streaming via SSE)
%%% - GET  /api/llm/health  - Backend health check
%%%
%%% @end
-module(hecate_api_llm).

-export([init/2]).

%% Route: GET /api/llm/models
init(Req0, [models]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_list_models(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: POST /api/llm/chat
init(Req0, [chat]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_chat(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/llm/health
init(Req0, [health]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_health(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

init(Req0, _State) ->
    not_found(Req0).

%%% ===================================================================
%%% Handlers
%%% ===================================================================

handle_list_models(Req0) ->
    case llm_backend:list_models() of
        {ok, Models} ->
            Response = #{
                ok => true,
                models => Models
            },
            json_response(200, Response, Req0);
        {error, {http_error, _Code, _Body}} ->
            json_response(503, #{
                ok => false,
                error => <<"LLM backend unavailable">>
            }, Req0);
        {error, Reason} ->
            json_response(500, #{
                ok => false,
                error => format_error(Reason)
            }, Req0)
    end.

handle_chat(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    try json:decode(Body) of
        Params ->
            Model = maps:get(<<"model">>, Params, undefined),
            Messages = maps:get(<<"messages">>, Params, []),
            Stream = maps:get(<<"stream">>, Params, false),

            case validate_chat_params(Model, Messages) of
                ok when Stream =:= true ->
                    handle_streaming_chat(Req1, Model, Messages, Params);
                ok ->
                    handle_sync_chat(Req1, Model, Messages, Params);
                {error, Reason} ->
                    json_response(400, #{ok => false, error => Reason}, Req1)
            end
    catch
        _:_ ->
            json_response(400, #{ok => false, error => <<"Invalid JSON">>}, Req1)
    end.

handle_sync_chat(Req0, Model, Messages, Params) ->
    Opts = build_chat_opts(Model, Params),
    FormattedMessages = format_messages(Messages),

    case llm_backend:chat(FormattedMessages, Opts) of
        {ok, Response} ->
            json_response(200, #{
                ok => true,
                response => Response
            }, Req0);
        {error, {http_error, Code, _Body}} when Code >= 500 ->
            json_response(503, #{
                ok => false,
                error => <<"LLM backend unavailable">>
            }, Req0);
        {error, Reason} ->
            json_response(500, #{
                ok => false,
                error => format_error(Reason)
            }, Req0)
    end.

handle_streaming_chat(Req0, Model, Messages, Params) ->
    BaseUrl = application:get_env(serve_llm, ollama_url, "http://localhost:11434"),
    Opts = build_chat_opts(Model, Params),
    FormattedMessages = format_messages(Messages),

    %% chat_stream always returns {ok, Ref}, errors come via messages
    {ok, Ref} = llm_backend:chat_stream(BaseUrl, FormattedMessages, Opts),
    %% Set up SSE response
    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>
    }, Req0),
    stream_chunks(Req1, Ref).

stream_chunks(Req, Ref) ->
    receive
        {llm_chunk, Ref, Chunk} ->
            Content = maps:get(content, Chunk, <<>>),
            Done = maps:get(done, Chunk, false),
            Event = #{
                content => Content,
                done => Done
            },
            %% Add usage info if done
            EventWithUsage = case Done of
                true ->
                    Event#{
                        model => maps:get(model, Chunk, <<>>),
                        usage => #{
                            prompt_tokens => maps:get(prompt_eval_count, Chunk, 0),
                            completion_tokens => maps:get(eval_count, Chunk, 0)
                        }
                    };
                false ->
                    Event
            end,
            Data = json:encode(EventWithUsage),
            cowboy_req:stream_body(<<"data: ", Data/binary, "\n\n">>, nofin, Req),
            stream_chunks(Req, Ref);
        {llm_done, Ref} ->
            cowboy_req:stream_body(<<"data: [DONE]\n\n">>, fin, Req),
            {ok, Req, []};
        {llm_error, Ref, Reason} ->
            ErrorData = json:encode(#{error => format_error(Reason)}),
            cowboy_req:stream_body(<<"data: ", ErrorData/binary, "\n\n">>, fin, Req),
            {ok, Req, []}
    after 120000 ->
        ErrorData = json:encode(#{error => <<"Timeout">>}),
        cowboy_req:stream_body(<<"data: ", ErrorData/binary, "\n\n">>, fin, Req),
        {ok, Req, []}
    end.

handle_health(Req0) ->
    case llm_backend:health() of
        ok ->
            json_response(200, #{
                ok => true,
                status => <<"healthy">>,
                backend => <<"ollama">>
            }, Req0);
        {error, {http_error, _Code, _Body}} ->
            json_response(503, #{
                ok => false,
                status => <<"unhealthy">>,
                error => <<"Backend unavailable">>
            }, Req0);
        {error, Reason} ->
            json_response(503, #{
                ok => false,
                status => <<"unhealthy">>,
                error => format_error(Reason)
            }, Req0)
    end.

%%% ===================================================================
%%% Helpers
%%% ===================================================================

validate_chat_params(undefined, _Messages) ->
    {error, <<"model is required">>};
validate_chat_params(_Model, []) ->
    {error, <<"messages cannot be empty">>};
validate_chat_params(_Model, Messages) when not is_list(Messages) ->
    {error, <<"messages must be an array">>};
validate_chat_params(_Model, _Messages) ->
    ok.

build_chat_opts(Model, Params) ->
    Opts = #{model => Model},
    Opts1 = case maps:get(<<"temperature">>, Params, undefined) of
        undefined -> Opts;
        Temp -> Opts#{temperature => Temp}
    end,
    case maps:get(<<"max_tokens">>, Params, undefined) of
        undefined -> Opts1;
        MaxTokens -> Opts1#{max_tokens => MaxTokens}
    end.

format_messages(Messages) ->
    lists:map(fun(M) ->
        #{
            role => maps:get(<<"role">>, M, <<"user">>),
            content => maps:get(<<"content">>, M, <<>>)
        }
    end, Messages).

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason);
format_error({Type, Details}) ->
    iolist_to_binary(io_lib:format("~p: ~p", [Type, Details]));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

json_response(StatusCode, Body, Req0) ->
    JsonBody = json:encode(Body),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, JsonBody, Req0),
    {ok, Req, []}.

method_not_allowed(Req0) ->
    json_response(405, #{ok => false, error => <<"Method not allowed">>}, Req0).

not_found(Req0) ->
    json_response(404, #{ok => false, error => <<"Not found">>}, Req0).
