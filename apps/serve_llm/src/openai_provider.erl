%%% @doc OpenAI-compatible LLM Provider
%%%
%%% Implements llm_provider behaviour for OpenAI-compatible APIs.
%%% Works with OpenAI, Groq, Together, and any OpenAI-compatible endpoint.
%%% @end
-module(openai_provider).
-behaviour(llm_provider).

-export([list_models/1, chat/4, chat_stream/6, health/1]).

%%% ===================================================================
%%% llm_provider callbacks
%%% ===================================================================

-spec list_models(map()) -> {ok, [map()]} | {error, term()}.
list_models(Config) ->
    Url = base_url(Config) ++ "/v1/models",
    Headers = auth_headers(Config),
    case hackney:get(Url, Headers, <<>>, [with_body]) of
        {ok, 200, _RespHeaders, Body} ->
            #{<<"data">> := RawModels} = json:decode(Body),
            Models = lists:filtermap(fun normalize_model/1, RawModels),
            {ok, Models};
        {ok, Status, _RespHeaders, RespBody} ->
            {error, {http_error, Status, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec chat(map(), binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Config, Model, Messages, Opts) ->
    Url = base_url(Config) ++ "/v1/chat/completions",
    Headers = [{<<"Content-Type">>, <<"application/json">>} | auth_headers(Config)],
    Body = json:encode(build_request(Model, Messages, Opts, false)),
    case hackney:post(Url, Headers, Body, [with_body]) of
        {ok, 200, _RespHeaders, RespBody} ->
            Decoded = json:decode(RespBody),
            {ok, normalize_response(Decoded)};
        {ok, Status, _RespHeaders, RespBody} ->
            {error, {http_error, Status, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec chat_stream(map(), binary(), list(), map(), pid(), reference()) -> ok.
chat_stream(Config, Model, Messages, Opts, Caller, Ref) ->
    Url = base_url(Config) ++ "/v1/chat/completions",
    Headers = [{<<"Content-Type">>, <<"application/json">>} | auth_headers(Config)],
    Body = json:encode(build_request(Model, Messages, Opts, true)),
    case hackney:post(Url, Headers, Body, [async]) of
        {ok, ClientRef} ->
            stream_loop(ClientRef, Ref, Caller, <<>>);
        {error, Reason} ->
            Caller ! {llm_error, Ref, Reason}
    end,
    ok.

-spec health(map()) -> ok | {error, term()}.
health(Config) ->
    Url = base_url(Config) ++ "/v1/models",
    Headers = auth_headers(Config),
    case hackney:get(Url, Headers, <<>>, [with_body, {recv_timeout, 5000}]) of
        {ok, 200, _Headers, _Body} -> ok;
        {ok, 401, _Headers, _Body} -> {error, unauthorized};
        {ok, Status, _Headers, _Body} -> {error, {http_status, Status}};
        {error, Reason} -> {error, Reason}
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

base_url(#{url := Url}) when is_list(Url) -> Url;
base_url(#{url := Url}) when is_binary(Url) -> binary_to_list(Url);
base_url(_) -> "https://api.openai.com".

auth_headers(#{api_key := Key}) when is_binary(Key), byte_size(Key) > 0 ->
    [{<<"Authorization">>, <<"Bearer ", Key/binary>>}];
auth_headers(_) ->
    [].

build_request(Model, Messages, Opts, Stream) ->
    Base = #{
        model => Model,
        messages => Messages,
        stream => Stream
    },
    Base1 = case maps:get(temperature, Opts, undefined) of
        undefined -> Base;
        Temp -> Base#{temperature => Temp}
    end,
    Base2 = case maps:get(max_tokens, Opts, undefined) of
        undefined -> Base1;
        MaxTokens -> Base1#{max_tokens => MaxTokens}
    end,
    %% Add tools if provided (OpenAI function calling format)
    case maps:get(tools, Opts, undefined) of
        undefined -> Base2;
        [] -> Base2;
        Tools when is_list(Tools) ->
            ToolSchemas = [tool_to_openai_schema(T) || T <- Tools],
            Base2#{tools => ToolSchemas}
    end.

%% @doc Convert tool definition to OpenAI's function calling format.
tool_to_openai_schema(#{name := Name, description := Desc, input_schema := Schema}) ->
    #{
        type => <<"function">>,
        function => #{
            name => Name,
            description => Desc,
            parameters => Schema
        }
    };
tool_to_openai_schema(#{<<"name">> := Name, <<"description">> := Desc, <<"input_schema">> := Schema}) ->
    #{
        type => <<"function">>,
        function => #{
            name => Name,
            description => Desc,
            parameters => Schema
        }
    }.

normalize_model(#{<<"id">> := Id} = M) ->
    OwnedBy = maps:get(<<"owned_by">>, M, <<"unknown">>),
    %% Filter out embedding/moderation/tts models
    case is_chat_model(Id) of
        true ->
            {true, #{
                name => Id,
                context_length => 0,
                family => OwnedBy,
                parameter_size => <<>>,
                format => <<"api">>
            }};
        false ->
            false
    end;
normalize_model(_) ->
    false.

is_chat_model(Id) ->
    not (binary:match(Id, <<"embedding">>) =/= nomatch
         orelse binary:match(Id, <<"embed">>) =/= nomatch
         orelse binary:match(Id, <<"tts">>) =/= nomatch
         orelse binary:match(Id, <<"whisper">>) =/= nomatch
         orelse binary:match(Id, <<"dall-e">>) =/= nomatch
         orelse binary:match(Id, <<"moderation">>) =/= nomatch).

normalize_response(#{<<"choices">> := [Choice | _]} = Resp) ->
    Message = maps:get(<<"message">>, Choice, #{}),
    Content = maps:get(<<"content">>, Message, <<>>),
    FinishReason = maps:get(<<"finish_reason">>, Choice, <<>>),
    Usage = maps:get(<<"usage">>, Resp, #{}),
    BaseResp = #{
        content => Content,
        model => maps:get(<<"model">>, Resp, <<>>),
        done => true,
        stop_reason => FinishReason,
        eval_count => maps:get(<<"completion_tokens">>, Usage, 0),
        prompt_eval_count => maps:get(<<"prompt_tokens">>, Usage, 0),
        message => #{role => <<"assistant">>, content => Content}
    },
    %% Handle tool calls
    case maps:get(<<"tool_calls">>, Message, undefined) of
        undefined -> BaseResp;
        [] -> BaseResp;
        ToolCalls when is_list(ToolCalls) ->
            NormalizedCalls = [normalize_tool_call(TC) || TC <- ToolCalls],
            BaseResp#{tool_calls => NormalizedCalls}
    end;
normalize_response(_) ->
    #{content => <<>>, done => true}.

normalize_tool_call(#{<<"id">> := Id, <<"function">> := Func}) ->
    Name = maps:get(<<"name">>, Func, <<>>),
    Args = maps:get(<<"arguments">>, Func, <<"{}">>),
    #{
        id => Id,
        name => Name,
        arguments => Args  %% JSON string in OpenAI format
    };
normalize_tool_call(_) ->
    #{id => <<>>, name => <<>>, arguments => <<"{}">>}.

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
            {Events, Rest} = parse_sse(NewBuffer),
            lists:foreach(fun(EventData) ->
                case EventData of
                    <<"[DONE]">> ->
                        Caller ! {llm_done, Ref};
                    _ ->
                        try json:decode(EventData) of
                            Decoded ->
                                Caller ! {llm_chunk, Ref, normalize_stream_chunk(Decoded)}
                        catch _:_ ->
                            ok
                        end
                end
            end, Events),
            stream_loop(ClientRef, Ref, Caller, Rest);
        {hackney_response, ClientRef, {error, Reason}} ->
            Caller ! {llm_error, Ref, Reason}
    after 120000 ->
        Caller ! {llm_error, Ref, timeout},
        hackney:close(ClientRef)
    end.

normalize_stream_chunk(#{<<"choices">> := [Choice | _]} = Resp) ->
    Delta = maps:get(<<"delta">>, Choice, #{}),
    Content = maps:get(<<"content">>, Delta, <<>>),
    FinishReason = maps:get(<<"finish_reason">>, Choice, null),
    Done = FinishReason =/= null,
    %% Use binary keys to match what hecate_api_llm expects
    Base = #{<<"content">> => Content, <<"done">> => Done},
    %% Handle tool calls in streaming delta
    Base1 = case maps:get(<<"tool_calls">>, Delta, undefined) of
        undefined -> Base;
        [] -> Base;
        ToolCalls when is_list(ToolCalls) ->
            %% Streaming tool calls come in deltas
            NormalizedCalls = [normalize_stream_tool_call(TC) || TC <- ToolCalls],
            Base#{<<"tool_call_deltas">> => NormalizedCalls}
    end,
    case Done of
        true ->
            Usage = maps:get(<<"usage">>, Resp, #{}),
            Base1#{
                <<"model">> => maps:get(<<"model">>, Resp, <<>>),
                <<"stop_reason">> => FinishReason,
                <<"eval_count">> => maps:get(<<"completion_tokens">>, Usage, 0),
                <<"prompt_eval_count">> => maps:get(<<"prompt_tokens">>, Usage, 0)
            };
        false ->
            Base1
    end;
normalize_stream_chunk(_) ->
    #{<<"content">> => <<>>, <<"done">> => false}.

normalize_stream_tool_call(#{<<"index">> := Index} = TC) ->
    Func = maps:get(<<"function">>, TC, #{}),
    %% Use binary keys for consistency
    Base = #{<<"index">> => Index},
    Base1 = case maps:get(<<"id">>, TC, undefined) of
        undefined -> Base;
        Id -> Base#{<<"id">> => Id}
    end,
    Base2 = case maps:get(<<"name">>, Func, undefined) of
        undefined -> Base1;
        Name -> Base1#{<<"name">> => Name}
    end,
    case maps:get(<<"arguments">>, Func, undefined) of
        undefined -> Base2;
        Args -> Base2#{<<"arguments_delta">> => Args}
    end;
normalize_stream_tool_call(_) ->
    #{}.

parse_sse(Buffer) ->
    Lines = binary:split(Buffer, <<"\n">>, [global]),
    parse_sse_lines(Lines, [], <<>>).

parse_sse_lines([], Acc, Rest) ->
    {lists:reverse(Acc), Rest};
parse_sse_lines([<<>>], Acc, _Rest) ->
    {lists:reverse(Acc), <<>>};
parse_sse_lines([Last], Acc, _Rest) ->
    {lists:reverse(Acc), Last};
parse_sse_lines([<<"data: ", Data/binary>> | Rest], Acc, _) ->
    parse_sse_lines(Rest, [Data | Acc], <<>>);
parse_sse_lines([<<>> | Rest], Acc, _) ->
    parse_sse_lines(Rest, Acc, <<>>);
parse_sse_lines([_Line | Rest], Acc, _) ->
    parse_sse_lines(Rest, Acc, <<>>).
