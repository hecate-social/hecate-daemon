%%% @doc Ollama LLM Provider
%%%
%%% Implements llm_provider behaviour for the local Ollama backend.
%%% Extracted from chat_to_llm, list_available_llms, and check_llm_health.
%%% @end
-module(ollama_provider).
-behaviour(llm_provider).

-export([list_models/1, chat/4, chat_stream/6, health/1]).

%%% ===================================================================
%%% llm_provider callbacks
%%% ===================================================================

-spec list_models(map()) -> {ok, [map()]} | {error, term()}.
list_models(Config) ->
    Url = base_url(Config) ++ "/api/tags",
    case hackney:get(Url, [], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            #{<<"models">> := RawModels} = json:decode(Body),
            Models = lists:map(fun normalize_model/1, RawModels),
            {ok, Models};
        {ok, Status, _Headers, _Body} ->
            {error, {http_status, Status}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec chat(map(), binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Config, Model, Messages, Opts) ->
    Url = base_url(Config) ++ "/api/chat",
    Body = json:encode(build_request(Model, Messages, Opts, false)),
    Headers = [{<<"Content-Type">>, <<"application/json">>}],
    %% Long timeout for model loading (Ollama may need to load large models)
    case hackney:post(Url, Headers, Body, [with_body, {recv_timeout, 300000}]) of
        {ok, 200, _RespHeaders, RespBody} ->
            {ok, normalize_response(json:decode(RespBody))};
        {ok, Status, _RespHeaders, RespBody} ->
            {error, {http_error, Status, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec chat_stream(map(), binary(), list(), map(), pid(), reference()) -> ok.
chat_stream(Config, Model, Messages, Opts, Caller, Ref) ->
    Url = base_url(Config) ++ "/api/chat",
    Body = json:encode(build_request(Model, Messages, Opts, true)),
    Headers = [{<<"Content-Type">>, <<"application/json">>}],
    %% Long recv_timeout for model loading (Ollama may need to load large models into GPU)
    case hackney:post(Url, Headers, Body, [async, {recv_timeout, 300000}]) of
        {ok, ClientRef} ->
            stream_loop(ClientRef, Ref, Caller, <<>>);
        {error, Reason} ->
            Caller ! {llm_error, Ref, Reason}
    end,
    ok.

-spec health(map()) -> ok | {error, term()}.
health(Config) ->
    Url = base_url(Config) ++ "/api/tags",
    case hackney:get(Url, [], <<>>, [with_body, {recv_timeout, 5000}]) of
        {ok, 200, _Headers, _Body} ->
            ok;
        {ok, Status, _Headers, _Body} ->
            {error, {http_status, Status}};
        {error, Reason} ->
            {error, Reason}
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

base_url(#{url := Url}) -> Url;
base_url(_) ->
    case os:getenv("OLLAMA_HOST") of
        false -> application:get_env(serve_llm, ollama_url, "http://localhost:11434");
        Url -> Url
    end.

%% Build request with optional tools support
%% Ollama uses OpenAI-compatible tool format for models that support it
%% (llama3.1, mistral-nemo, firefunction-v2, command-r+)
build_request(Model, Messages, Opts, Stream) ->
    Base = #{
        model => Model,
        messages => [format_msg_for_ollama(M) || M <- Messages],
        stream => Stream,
        options => maps:get(options, Opts, #{})
    },
    %% Add tools if provided (Ollama uses OpenAI-compatible format)
    case maps:get(tools, Opts, undefined) of
        undefined -> Base;
        [] -> Base;
        Tools when is_list(Tools) ->
            ToolSchemas = [tool_to_ollama_schema(T) || T <- Tools],
            Base#{tools => ToolSchemas}
    end.

%% Convert tool definition to Ollama's format (OpenAI-compatible)
tool_to_ollama_schema(#{name := Name, description := Desc, input_schema := Schema}) ->
    #{
        type => <<"function">>,
        function => #{
            name => Name,
            description => Desc,
            parameters => Schema
        }
    };
tool_to_ollama_schema(#{<<"name">> := Name, <<"description">> := Desc, <<"input_schema">> := Schema}) ->
    #{
        type => <<"function">>,
        function => #{
            name => Name,
            description => Desc,
            parameters => Schema
        }
    }.

%% Convert a message to Ollama's expected format.
%% Restores tool_calls from normalized {id, name, arguments} back to
%% OpenAI format {id, type, function: {name, arguments_string}}.
format_msg_for_ollama(#{tool_calls := ToolCalls} = Msg) when is_list(ToolCalls), ToolCalls =/= [] ->
    OllamaCalls = [tool_call_to_ollama(TC) || TC <- ToolCalls],
    Msg#{tool_calls => OllamaCalls};
format_msg_for_ollama(Msg) ->
    Msg.

tool_call_to_ollama(TC) ->
    Id = get_field(id, <<"id">>, TC, <<>>),
    Name = get_field(name, <<"name">>, TC, <<>>),
    Args = get_field(arguments, <<"arguments">>, TC, #{}),
    %% Ollama expects arguments as a JSON object, not a string
    ArgsMap = case is_binary(Args) of
        true -> try json:decode(Args) catch _:_ -> #{} end;
        false -> Args
    end,
    #{
        id => Id,
        type => <<"function">>,
        function => #{
            name => Name,
            arguments => ArgsMap
        }
    }.

%% Get a field by atom key first, then binary key fallback
get_field(AtomKey, BinKey, Map, Default) ->
    case maps:get(AtomKey, Map, undefined) of
        undefined -> maps:get(BinKey, Map, Default);
        Val -> Val
    end.

%% Normalize response to include tool_calls if present
normalize_response(#{<<"message">> := Message} = Resp) ->
    Content = maps:get(<<"content">>, Message, <<>>),
    BaseResp = Resp#{
        content => Content,
        done => maps:get(<<"done">>, Resp, true)
    },
    %% Handle tool calls from Ollama
    case maps:get(<<"tool_calls">>, Message, undefined) of
        undefined -> BaseResp;
        [] -> BaseResp;
        ToolCalls when is_list(ToolCalls) ->
            NormalizedCalls = [normalize_tool_call(TC) || TC <- ToolCalls],
            BaseResp#{tool_calls => NormalizedCalls}
    end;
normalize_response(Resp) ->
    Resp.

normalize_tool_call(#{<<"function">> := Func} = TC) ->
    Name = maps:get(<<"name">>, Func, <<>>),
    Args = maps:get(<<"arguments">>, Func, #{}),
    #{
        id => maps:get(<<"id">>, TC, generate_tool_id()),
        name => Name,
        arguments => Args
    };
normalize_tool_call(_) ->
    #{id => <<>>, name => <<>>, arguments => #{}}.

generate_tool_id() ->
    <<H:64, L:64>> = crypto:strong_rand_bytes(16),
    iolist_to_binary(io_lib:format("call_~16.16.0b~16.16.0b", [H, L])).

%% Normalize streaming chunk - use binary keys for hecate_api_llm compatibility
normalize_stream_chunk(#{<<"message">> := Message} = Chunk) ->
    Content = maps:get(<<"content">>, Message, <<>>),
    Done = maps:get(<<"done">>, Chunk, false),
    Base = #{<<"content">> => Content, <<"done">> => Done},
    %% Handle tool calls in streaming
    Base1 = case maps:get(<<"tool_calls">>, Message, undefined) of
        undefined -> Base;
        [] -> Base;
        ToolCalls when is_list(ToolCalls) ->
            NormalizedCalls = [normalize_tool_call(TC) || TC <- ToolCalls],
            Base#{<<"tool_calls">> => NormalizedCalls}
    end,
    %% Add usage stats if done
    case Done of
        true ->
            Base1#{
                <<"eval_count">> => maps:get(<<"eval_count">>, Chunk, 0),
                <<"prompt_eval_count">> => maps:get(<<"prompt_eval_count">>, Chunk, 0)
            };
        false ->
            Base1
    end;
normalize_stream_chunk(Chunk) ->
    %% Fallback: convert to binary keys
    Done = maps:get(<<"done">>, Chunk, maps:get(done, Chunk, false)),
    Content = maps:get(<<"content">>, Chunk, maps:get(content, Chunk, <<>>)),
    #{<<"content">> => Content, <<"done">> => Done}.

normalize_model(OllamaModel) ->
    Name = maps:get(<<"name">>, OllamaModel, <<"unknown">>),
    Details = maps:get(<<"details">>, OllamaModel, #{}),
    #{
        name => Name,
        context_length => maps:get(<<"context_length">>, Details, 4096),
        family => maps:get(<<"family">>, Details, <<"unknown">>),
        parameter_size => maps:get(<<"parameter_size">>, Details, <<"unknown">>),
        quantization => maps:get(<<"quantization_level">>, Details, <<"unknown">>),
        size_bytes => maps:get(<<"size">>, OllamaModel, 0),
        format => maps:get(<<"format">>, Details, <<"unknown">>)
    }.

stream_loop(ClientRef, Ref, Caller, Buffer) ->
    receive
        {hackney_response, ClientRef, {status, 200, _}} ->
            stream_loop(ClientRef, Ref, Caller, Buffer);
        {hackney_response, ClientRef, {status, Status, _}} ->
            Caller ! {llm_error, Ref, {http_status, Status}},
            hackney:close(ClientRef);
        {hackney_response, ClientRef, {headers, _Headers}} ->
            stream_loop(ClientRef, Ref, Caller, Buffer);
        {hackney_response, ClientRef, done} ->
            Caller ! {llm_done, Ref};
        {hackney_response, ClientRef, Chunk} when is_binary(Chunk) ->
            NewBuffer = <<Buffer/binary, Chunk/binary>>,
            {Parsed, Rest} = parse_ndjson(NewBuffer),
            lists:foreach(fun(ChunkMap) ->
                Caller ! {llm_chunk, Ref, normalize_stream_chunk(ChunkMap)}
            end, Parsed),
            stream_loop(ClientRef, Ref, Caller, Rest);
        {hackney_response, ClientRef, {error, Reason}} ->
            Caller ! {llm_error, Ref, Reason}
    after 120000 ->
        Caller ! {llm_error, Ref, timeout},
        hackney:close(ClientRef)
    end.

parse_ndjson(Buffer) ->
    Lines = binary:split(Buffer, <<"\n">>, [global]),
    parse_lines(Lines, [], <<>>).

parse_lines([], Acc, Rest) ->
    {lists:reverse(Acc), Rest};
parse_lines([<<>>], Acc, _Rest) ->
    {lists:reverse(Acc), <<>>};
parse_lines([Last], Acc, _Rest) ->
    {lists:reverse(Acc), Last};
parse_lines([Line | Rest], Acc, _) ->
    case catch json:decode(Line) of
        {'EXIT', _} ->
            parse_lines(Rest, Acc, <<>>);
        Decoded ->
            parse_lines(Rest, [Decoded | Acc], <<>>)
    end.
