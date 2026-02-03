%%% @doc LLM backend client - talks to Ollama (or compatible) inference servers.
%%%
%%% This module provides the interface to local LLM inference.
%%% Currently supports Ollama API at localhost:11434.
%%%
%%% @end
-module(llm_backend).

-export([
    chat/2,
    chat/3,
    chat_stream/3,
    list_models/0,
    list_models/1,
    health/0,
    health/1
]).

-type message() :: #{
    role := binary(),      %% <<"system">> | <<"user">> | <<"assistant">>
    content := binary()
}.

-type chat_opts() :: #{
    model := binary(),
    temperature => float(),
    max_tokens => integer(),
    stream => boolean()
}.

-type chat_response() :: #{
    content := binary(),
    model := binary(),
    done := boolean(),
    total_duration => integer(),
    prompt_eval_count => integer(),
    eval_count => integer()
}.

-type model_info() :: #{
    name := binary(),
    size := integer(),
    modified_at := binary(),
    digest := binary()
}.

-export_type([message/0, chat_opts/0, chat_response/0, model_info/0]).

%% Dialyzer: Allow overly general specs for public API
-dialyzer({nowarn_function, [chat/2, chat/3]}).

%%% ===================================================================
%%% API Functions
%%% ===================================================================

%% @doc Chat completion with default backend URL
-spec chat([message()], chat_opts()) -> {ok, chat_response()} | {error, term()}.
chat(Messages, Opts) ->
    BaseUrl = get_base_url(),
    chat(BaseUrl, Messages, Opts).

%% @doc Chat completion with explicit backend URL
-spec chat(binary() | string(), [message()], chat_opts()) -> {ok, chat_response()} | {error, term()}.
chat(BaseUrl, Messages, Opts) ->
    Url = iolist_to_binary([to_binary(BaseUrl), <<"/api/chat">>]),
    Model = maps:get(model, Opts),

    Body = #{
        model => Model,
        messages => Messages,
        stream => false,
        options => build_options(Opts)
    },

    case do_post(Url, Body) of
        {ok, 200, _Headers, RespBody} ->
            parse_chat_response(RespBody);
        {ok, StatusCode, _Headers, RespBody} ->
            {error, {http_error, StatusCode, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Streaming chat - sends chunks to caller process
%% Caller will receive messages:
%%   {llm_chunk, Ref, Chunk} - partial response
%%   {llm_done, Ref} - stream complete
%%   {llm_error, Ref, Reason} - error occurred
%% Always returns {ok, Ref} - errors are delivered via messages
-spec chat_stream(binary() | string(), [message()], chat_opts()) -> {ok, reference()}.
chat_stream(BaseUrl, Messages, Opts) ->
    Url = iolist_to_binary([to_binary(BaseUrl), <<"/api/chat">>]),
    Model = maps:get(model, Opts),
    CallerPid = self(),

    Body = #{
        model => Model,
        messages => Messages,
        stream => true,
        options => build_options(Opts)
    },

    Ref = make_ref(),
    spawn_link(fun() -> stream_request(CallerPid, Ref, Url, Body) end),
    {ok, Ref}.

%% @doc List available models from default backend
-spec list_models() -> {ok, [model_info()]} | {error, term()}.
list_models() ->
    BaseUrl = get_base_url(),
    list_models(BaseUrl).

%% @doc List available models from explicit backend URL
-spec list_models(binary() | string()) -> {ok, [model_info()]} | {error, term()}.
list_models(BaseUrl) ->
    Url = iolist_to_binary([to_binary(BaseUrl), <<"/api/tags">>]),

    case do_get(Url) of
        {ok, 200, _Headers, RespBody} ->
            parse_models_response(RespBody);
        {ok, StatusCode, _Headers, RespBody} ->
            {error, {http_error, StatusCode, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Health check default backend
-spec health() -> ok | {error, term()}.
health() ->
    BaseUrl = get_base_url(),
    health(BaseUrl).

%% @doc Health check explicit backend URL
-spec health(binary() | string()) -> ok | {error, term()}.
health(BaseUrl) ->
    %% Ollama doesn't have a dedicated health endpoint, so we use /api/tags
    %% which is lightweight and returns quickly
    Url = iolist_to_binary([to_binary(BaseUrl), <<"/api/tags">>]),

    case do_get(Url) of
        {ok, 200, _Headers, _RespBody} ->
            ok;
        {ok, StatusCode, _Headers, RespBody} ->
            {error, {http_error, StatusCode, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

%%% ===================================================================
%%% Internal Functions
%%% ===================================================================

get_base_url() ->
    %% Priority: OLLAMA_HOST env var > app config > default
    %% OLLAMA_HOST is set by Docker to reach host's Ollama
    case os:getenv("OLLAMA_HOST") of
        false ->
            case application:get_env(serve_llm, ollama_url) of
                {ok, Url} -> to_binary(Url);
                undefined -> <<"http://localhost:11434">>
            end;
        EnvUrl ->
            to_binary(EnvUrl)
    end.

to_binary(B) when is_binary(B) -> B;
to_binary(L) when is_list(L) -> list_to_binary(L).

build_options(Opts) ->
    Options = #{},
    Options1 = case maps:get(temperature, Opts, undefined) of
        undefined -> Options;
        Temp -> Options#{temperature => Temp}
    end,
    case maps:get(max_tokens, Opts, undefined) of
        undefined -> Options1;
        MaxTokens -> Options1#{num_predict => MaxTokens}
    end.

do_get(Url) ->
    case hackney:get(Url, [{<<"Accept">>, <<"application/json">>}], <<>>, [with_body]) of
        {ok, StatusCode, Headers, Body} ->
            {ok, StatusCode, Headers, Body};
        {error, Reason} ->
            {error, Reason}
    end.

do_post(Url, Body) ->
    JsonBody = json:encode(Body),
    Headers = [
        {<<"Content-Type">>, <<"application/json">>},
        {<<"Accept">>, <<"application/json">>}
    ],
    case hackney:post(Url, Headers, JsonBody, [with_body]) of
        {ok, StatusCode, RespHeaders, RespBody} ->
            {ok, StatusCode, RespHeaders, RespBody};
        {error, Reason} ->
            {error, Reason}
    end.

parse_chat_response(Body) ->
    try
        Decoded = json:decode(Body),
        Message = maps:get(<<"message">>, Decoded, #{}),
        Content = maps:get(<<"content">>, Message, <<>>),
        {ok, #{
            content => Content,
            model => maps:get(<<"model">>, Decoded, <<>>),
            done => maps:get(<<"done">>, Decoded, true),
            total_duration => maps:get(<<"total_duration">>, Decoded, 0),
            prompt_eval_count => maps:get(<<"prompt_eval_count">>, Decoded, 0),
            eval_count => maps:get(<<"eval_count">>, Decoded, 0)
        }}
    catch
        _:Error ->
            {error, {json_decode_error, Error, Body}}
    end.

parse_models_response(Body) ->
    try
        Decoded = json:decode(Body),
        Models = maps:get(<<"models">>, Decoded, []),
        Parsed = lists:map(fun(M) ->
            #{
                name => maps:get(<<"name">>, M, <<>>),
                size => maps:get(<<"size">>, M, 0),
                modified_at => maps:get(<<"modified_at">>, M, <<>>),
                digest => maps:get(<<"digest">>, M, <<>>)
            }
        end, Models),
        {ok, Parsed}
    catch
        _:Error ->
            {error, {json_decode_error, Error, Body}}
    end.

stream_request(CallerPid, Ref, Url, Body) ->
    JsonBody = json:encode(Body),
    Headers = [
        {<<"Content-Type">>, <<"application/json">>},
        {<<"Accept">>, <<"application/x-ndjson">>}
    ],

    case hackney:post(Url, Headers, JsonBody, [async]) of
        {ok, ClientRef} ->
            stream_loop(CallerPid, Ref, ClientRef, <<>>);
        {error, Reason} ->
            CallerPid ! {llm_error, Ref, Reason}
    end.

stream_loop(CallerPid, Ref, ClientRef, Buffer) ->
    receive
        {hackney_response, ClientRef, {status, 200, _Reason}} ->
            stream_loop(CallerPid, Ref, ClientRef, Buffer);
        {hackney_response, ClientRef, {status, StatusCode, Reason}} ->
            CallerPid ! {llm_error, Ref, {http_error, StatusCode, Reason}};
        {hackney_response, ClientRef, {headers, _Headers}} ->
            stream_loop(CallerPid, Ref, ClientRef, Buffer);
        {hackney_response, ClientRef, done} ->
            %% Process any remaining buffer
            process_buffer(CallerPid, Ref, Buffer),
            CallerPid ! {llm_done, Ref};
        {hackney_response, ClientRef, Chunk} when is_binary(Chunk) ->
            NewBuffer = <<Buffer/binary, Chunk/binary>>,
            RemainingBuffer = process_buffer(CallerPid, Ref, NewBuffer),
            stream_loop(CallerPid, Ref, ClientRef, RemainingBuffer);
        {hackney_response, ClientRef, {error, Reason}} ->
            CallerPid ! {llm_error, Ref, Reason}
    after 60000 ->
        CallerPid ! {llm_error, Ref, timeout},
        hackney:close(ClientRef)
    end.

process_buffer(CallerPid, Ref, Buffer) ->
    %% NDJSON: each line is a separate JSON object
    Lines = binary:split(Buffer, <<"\n">>, [global]),
    process_lines(CallerPid, Ref, Lines).

process_lines(_CallerPid, _Ref, [LastPart]) ->
    %% Last part might be incomplete, return as buffer
    LastPart;
process_lines(CallerPid, Ref, [Line | Rest]) ->
    case Line of
        <<>> ->
            process_lines(CallerPid, Ref, Rest);
        _ ->
            try
                Decoded = json:decode(Line),
                Message = maps:get(<<"message">>, Decoded, #{}),
                Content = maps:get(<<"content">>, Message, <<>>),
                Done = maps:get(<<"done">>, Decoded, false),

                case Done of
                    true ->
                        CallerPid ! {llm_chunk, Ref, #{
                            content => Content,
                            done => true,
                            model => maps:get(<<"model">>, Decoded, <<>>),
                            total_duration => maps:get(<<"total_duration">>, Decoded, 0),
                            prompt_eval_count => maps:get(<<"prompt_eval_count">>, Decoded, 0),
                            eval_count => maps:get(<<"eval_count">>, Decoded, 0)
                        }};
                    false ->
                        CallerPid ! {llm_chunk, Ref, #{content => Content, done => false}}
                end
            catch
                _:_ ->
                    %% Ignore malformed JSON lines
                    ok
            end,
            process_lines(CallerPid, Ref, Rest)
    end.
