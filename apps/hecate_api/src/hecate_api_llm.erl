%%% @doc LLM API endpoints.
%%%
%%% Provides REST interface to LLM inference (multi-provider):
%%% - GET  /api/llm/models          - List available models (all providers)
%%% - POST /api/llm/chat            - Chat completion (supports streaming via SSE)
%%% - GET  /api/llm/health          - Backend health check (all providers)
%%% - GET  /api/llm/providers       - List configured providers
%%% - POST /api/llm/providers/add   - Add a provider
%%% - POST /api/llm/providers/reload - Reload providers (re-detect from env vars)
%%% - POST /api/llm/providers/:name/remove - Remove a provider
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

%% Route: GET /api/llm/providers
init(Req0, [providers]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_list_providers(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: POST /api/llm/providers/add
init(Req0, [add_provider]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_add_provider(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: POST /api/llm/providers/:name/remove
init(Req0, [remove_provider]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_remove_provider(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: POST /api/llm/providers/reload
init(Req0, [reload_providers]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_reload_providers(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

init(Req0, _State) ->
    not_found(Req0).

%%% ===================================================================
%%% Handlers
%%% ===================================================================

handle_list_models(Req0) ->
    case list_available_llms:list() of
        {ok, Models} ->
            json_response(200, #{ok => true, models => Models}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
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

    case chat_to_llm:chat(Model, FormattedMessages, Opts) of
        {ok, Response} ->
            json_response(200, #{ok => true, response => Response}, Req0);
        {error, {unknown_model, _}} ->
            json_response(404, #{ok => false, error => <<"Model not found in any provider">>}, Req0);
        {error, {http_error, Code, _Body}} when Code >= 500 ->
            json_response(503, #{ok => false, error => <<"LLM backend unavailable">>}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

handle_streaming_chat(Req0, Model, Messages, Params) ->
    Opts = build_chat_opts(Model, Params),
    FormattedMessages = format_messages(Messages),

    case chat_to_llm:chat_stream(Model, FormattedMessages, Opts) of
        {ok, Ref} ->
            Req1 = cowboy_req:stream_reply(200, #{
                <<"content-type">> => <<"text/event-stream">>,
                <<"cache-control">> => <<"no-cache">>,
                <<"connection">> => <<"keep-alive">>
            }, Req0),
            stream_chunks(Req1, Ref);
        {error, {unknown_model, _}} ->
            json_response(404, #{ok => false, error => <<"Model not found in any provider">>}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

stream_chunks(Req, Ref) ->
    stream_chunks(Req, Ref, #{}).

stream_chunks(Req, Ref, State) ->
    receive
        {llm_chunk, Ref, Chunk} ->
            %% Ollama puts content inside "message", OpenAI at top level
            Content = case maps:get(<<"message">>, Chunk, undefined) of
                #{<<"content">> := C} -> C;
                _ -> maps:get(<<"content">>, Chunk, <<>>)
            end,
            Done = maps:get(<<"done">>, Chunk, false),
            StopReason = maps:get(<<"done_reason">>, Chunk, maps:get(<<"stop_reason">>, Chunk, undefined)),
            Event = #{content => Content, done => Done},

            %% Handle tool calls in chunk (OpenAI streaming format)
            Event1 = case maps:get(<<"tool_calls">>, Chunk, undefined) of
                undefined -> Event;
                ToolCalls when is_list(ToolCalls) ->
                    %% Full tool calls (non-streaming or final)
                    Msg = #{
                        role => <<"assistant">>,
                        content => Content,
                        tool_calls => [format_tool_call(TC) || TC <- ToolCalls]
                    },
                    Event#{message => Msg}
            end,

            %% Add stop_reason if present
            Event2 = case StopReason of
                undefined -> Event1;
                null -> Event1;
                Reason -> Event1#{stop_reason => Reason}
            end,

            EventWithUsage = case Done of
                true ->
                    Event2#{
                        model => maps:get(<<"model">>, Chunk, <<>>),
                        usage => #{
                            prompt_tokens => maps:get(<<"prompt_eval_count">>, Chunk, 0),
                            completion_tokens => maps:get(<<"eval_count">>, Chunk, 0)
                        }
                    };
                false ->
                    Event2
            end,
            Data = iolist_to_binary(json:encode(EventWithUsage)),
            cowboy_req:stream_body(<<"data: ", Data/binary, "\n\n">>, nofin, Req),
            stream_chunks(Req, Ref, State);

        %% Tool use start (Anthropic streaming)
        {llm_tool_use_start, Ref, ToolInfo} ->
            %% Start accumulating tool input
            Id = maps:get(id, ToolInfo, <<>>),
            Name = maps:get(name, ToolInfo, <<>>),
            NewState = State#{current_tool => #{id => Id, name => Name, input => <<>>}},
            stream_chunks(Req, Ref, NewState);

        %% Tool input delta (Anthropic streaming)
        {llm_tool_input_delta, Ref, PartialJson} ->
            %% Accumulate JSON input
            CurrentTool = maps:get(current_tool, State, #{input => <<>>}),
            CurrentInput = maps:get(input, CurrentTool, <<>>),
            NewInput = <<CurrentInput/binary, PartialJson/binary>>,
            NewTool = CurrentTool#{input => NewInput},
            NewState = State#{current_tool => NewTool},
            stream_chunks(Req, Ref, NewState);

        %% Content block stop (Anthropic streaming)
        {llm_content_block_stop, Ref} ->
            %% If we have a current tool, emit it as a complete tool_use
            case maps:get(current_tool, State, undefined) of
                undefined ->
                    stream_chunks(Req, Ref, State);
                Tool ->
                    %% Get the accumulated input JSON and decode it to avoid double-encoding
                    InputJson = maps:get(input, Tool, <<"{}">>),
                    InputMap = try json:decode(InputJson) catch _:_ -> #{} end,
                    ToolUse = #{
                        id => maps:get(id, Tool, <<>>),
                        name => maps:get(name, Tool, <<>>),
                        arguments => InputMap
                    },
                    Event = #{
                        done => false,
                        content => <<>>,
                        tool_use => ToolUse
                    },
                    Data = iolist_to_binary(json:encode(Event)),
                    cowboy_req:stream_body(<<"data: ", Data/binary, "\n\n">>, nofin, Req),
                    NewState = maps:remove(current_tool, State),
                    stream_chunks(Req, Ref, NewState)
            end;

        {llm_done, Ref} ->
            cowboy_req:stream_body(<<"data: [DONE]\n\n">>, fin, Req),
            {ok, Req, []};
        {llm_error, Ref, Reason} ->
            ErrorData = iolist_to_binary(json:encode(#{error => format_error(Reason)})),
            cowboy_req:stream_body(<<"data: ", ErrorData/binary, "\n\n">>, fin, Req),
            {ok, Req, []}
    after 300000 ->
        %% 5-minute timeout for model loading (matches provider recv_timeout)
        ErrorData = iolist_to_binary(json:encode(#{error => <<"Timeout waiting for LLM response">>})),
        cowboy_req:stream_body(<<"data: ", ErrorData/binary, "\n\n">>, fin, Req),
        {ok, Req, []}
    end.

%% Format a tool call for JSON output
%% Decode arguments if they're a JSON string to avoid double-encoding
format_tool_call(#{id := Id, name := Name, arguments := Args}) ->
    DecodedArgs = case is_binary(Args) of
        true -> try json:decode(Args) catch _:_ -> #{} end;
        false -> Args
    end,
    #{
        id => Id,
        name => Name,
        arguments => DecodedArgs
    };
format_tool_call(TC) ->
    TC.

handle_health(Req0) ->
    ProviderHealth = check_llm_health:check_all(),
    AnyHealthy = maps:fold(fun(_Name, ok, _) -> true;
                              (_Name, _, Acc) -> Acc
                           end, false, ProviderHealth),
    Status = case AnyHealthy of
        true -> <<"healthy">>;
        false -> <<"unhealthy">>
    end,
    StatusCode = case AnyHealthy of
        true -> 200;
        false -> 503
    end,
    Providers = maps:map(fun(_Name, ok) -> <<"healthy">>;
                            (_Name, {error, Reason}) -> format_error(Reason)
                         end, ProviderHealth),
    json_response(StatusCode, #{
        ok => AnyHealthy,
        status => Status,
        providers => Providers
    }, Req0).

handle_list_providers(Req0) ->
    Providers = manage_providers:list(),
    %% Convert to JSON-safe format (atoms to binaries)
    JsonProviders = maps:map(fun(_Name, Config) ->
        Type = maps:get(type, Config, unknown),
        Base = #{
            type => atom_to_binary(Type, utf8),
            enabled => maps:get(enabled, Config, true)
        },
        case maps:get(url, Config, undefined) of
            undefined -> Base;
            Url when is_list(Url) -> Base#{url => list_to_binary(Url)};
            Url -> Base#{url => Url}
        end
    end, Providers),
    json_response(200, #{ok => true, providers => JsonProviders}, Req0).

handle_add_provider(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    try json:decode(Body) of
        Params ->
            Name = maps:get(<<"name">>, Params, undefined),
            TypeBin = maps:get(<<"type">>, Params, undefined),
            ApiKey = maps:get(<<"api_key">>, Params, <<>>),
            Url = maps:get(<<"url">>, Params, <<>>),

            case validate_add_provider(Name, TypeBin) of
                {ok, Type} ->
                    Config = build_provider_config(Type, ApiKey, Url),
                    case manage_providers:add(Name, Type, Config) of
                        ok ->
                            manage_providers:refresh_models(),
                            json_response(200, #{ok => true}, Req1);
                        {error, Reason} ->
                            json_response(400, #{ok => false, error => format_error(Reason)}, Req1)
                    end;
                {error, Reason} ->
                    json_response(400, #{ok => false, error => Reason}, Req1)
            end
    catch
        _:_ ->
            json_response(400, #{ok => false, error => <<"Invalid JSON">>}, Req1)
    end.

handle_remove_provider(Req0) ->
    Name = cowboy_req:binding(name, Req0),
    case manage_providers:remove(Name) of
        ok ->
            manage_providers:refresh_models(),
            json_response(200, #{ok => true}, Req0);
        {error, cannot_remove_default} ->
            json_response(400, #{ok => false, error => <<"Cannot remove default Ollama provider">>}, Req0);
        {error, not_found} ->
            json_response(404, #{ok => false, error => <<"Provider not found">>}, Req0)
    end.

handle_reload_providers(Req0) ->
    ok = manage_providers:reload(),
    Providers = manage_providers:list(),
    ProviderNames = maps:keys(Providers),
    json_response(200, #{ok => true, providers => ProviderNames}, Req0).

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

validate_add_provider(undefined, _) ->
    {error, <<"name is required">>};
validate_add_provider(_, undefined) ->
    {error, <<"type is required">>};
validate_add_provider(_, TypeBin) ->
    case TypeBin of
        <<"ollama">> -> {ok, ollama};
        <<"openai">> -> {ok, openai};
        <<"anthropic">> -> {ok, anthropic};
        <<"google">> -> {ok, google};
        _ -> {error, <<"type must be one of: ollama, openai, anthropic, google">>}
    end.

build_provider_config(ollama, _ApiKey, Url) ->
    case Url of
        <<>> -> #{};
        _ -> #{url => binary_to_list(Url)}
    end;
build_provider_config(Type, ApiKey, Url) ->
    DefaultUrl = default_url(Type),
    UrlStr = case Url of
        <<>> -> DefaultUrl;
        _ -> binary_to_list(Url)
    end,
    Base = #{url => UrlStr},
    case ApiKey of
        <<>> -> Base;
        _ -> Base#{api_key => ApiKey}
    end.

default_url(openai) -> "https://api.openai.com";
default_url(anthropic) -> "https://api.anthropic.com";
default_url(google) -> "https://generativelanguage.googleapis.com".

build_chat_opts(Model, Params) ->
    Opts = #{model => Model},
    Opts1 = case maps:get(<<"temperature">>, Params, undefined) of
        undefined -> Opts;
        Temp -> Opts#{temperature => Temp}
    end,
    Opts2 = case maps:get(<<"max_tokens">>, Params, undefined) of
        undefined -> Opts1;
        MaxTokens -> Opts1#{max_tokens => MaxTokens}
    end,
    %% Add tools if provided (for function calling)
    case maps:get(<<"tools">>, Params, undefined) of
        undefined -> Opts2;
        [] -> Opts2;
        Tools when is_list(Tools) -> Opts2#{tools => Tools}
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
