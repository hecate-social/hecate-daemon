%%% @doc Google Gemini LLM Provider
%%%
%%% Implements llm_provider behaviour for the Google Gemini (Generative AI) API.
%%% @end
-module(google_provider).
-behaviour(llm_provider).

-export([list_models/1, chat/4, chat_stream/6, health/1]).

%%% ===================================================================
%%% llm_provider callbacks
%%% ===================================================================

-spec list_models(map()) -> {ok, [map()]} | {error, term()}.
list_models(Config) ->
    Url = base_url(Config) ++ "/v1beta/models?key=" ++ api_key_str(Config),
    case hackney:get(Url, [], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            #{<<"models">> := RawModels} = json:decode(Body),
            Models = lists:filtermap(fun normalize_model/1, RawModels),
            {ok, Models};
        {ok, Status, _Headers, RespBody} ->
            {error, {http_error, Status, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec chat(map(), binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Config, Model, Messages, Opts) ->
    Url = base_url(Config) ++ "/v1beta/models/" ++ binary_to_list(Model)
        ++ ":generateContent?key=" ++ api_key_str(Config),
    Headers = [{<<"Content-Type">>, <<"application/json">>}],
    {SystemInstruction, Contents} = extract_system(Messages),
    Body = json:encode(build_request(SystemInstruction, Contents, Opts)),
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
    Url = base_url(Config) ++ "/v1beta/models/" ++ binary_to_list(Model)
        ++ ":streamGenerateContent?alt=sse&key=" ++ api_key_str(Config),
    Headers = [{<<"Content-Type">>, <<"application/json">>}],
    {SystemInstruction, Contents} = extract_system(Messages),
    Body = json:encode(build_request(SystemInstruction, Contents, Opts)),
    case hackney:post(Url, Headers, Body, [async]) of
        {ok, ClientRef} ->
            stream_loop(ClientRef, Ref, Caller, <<>>);
        {error, Reason} ->
            Caller ! {llm_error, Ref, Reason}
    end,
    ok.

-spec health(map()) -> ok | {error, term()}.
health(Config) ->
    Url = base_url(Config) ++ "/v1beta/models?key=" ++ api_key_str(Config) ++ "&pageSize=1",
    case hackney:get(Url, [], <<>>, [with_body, {recv_timeout, 5000}]) of
        {ok, 200, _Headers, _Body} -> ok;
        {ok, 401, _Headers, _Body} -> {error, unauthorized};
        {ok, 403, _Headers, _Body} -> {error, forbidden};
        {ok, Status, _Headers, _Body} -> {error, {http_status, Status}};
        {error, Reason} -> {error, Reason}
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

base_url(#{url := Url}) when is_list(Url) -> Url;
base_url(#{url := Url}) when is_binary(Url) -> binary_to_list(Url);
base_url(_) -> "https://generativelanguage.googleapis.com".

api_key_str(#{api_key := Key}) when is_binary(Key) -> binary_to_list(Key);
api_key_str(#{api_key := Key}) when is_list(Key) -> Key;
api_key_str(_) -> "".

%% Gemini uses a different message format: "contents" with "parts"
%% and system instructions are a separate top-level field.
extract_system(Messages) ->
    extract_system(Messages, undefined, []).

extract_system([], System, Acc) ->
    {System, lists:reverse(Acc)};
extract_system([#{role := <<"system">>} = M | Rest], _System, Acc) ->
    Content = maps:get(content, M, <<>>),
    extract_system(Rest, #{parts => [#{text => Content}]}, Acc);
extract_system([#{<<"role">> := <<"system">>} = M | Rest], _System, Acc) ->
    Content = maps:get(<<"content">>, M, <<>>),
    extract_system(Rest, #{parts => [#{text => Content}]}, Acc);
extract_system([M | Rest], System, Acc) ->
    Role = gemini_role(maps:get(role, M, maps:get(<<"role">>, M, <<"user">>))),
    Content = maps:get(content, M, maps:get(<<"content">>, M, <<>>)),
    extract_system(Rest, System, [#{role => Role, parts => [#{text => Content}]} | Acc]).

gemini_role(<<"assistant">>) -> <<"model">>;
gemini_role(Role) -> Role.

build_request(SystemInstruction, Contents, Opts) ->
    Base = #{contents => Contents},
    Base1 = case SystemInstruction of
        undefined -> Base;
        _ -> Base#{systemInstruction => SystemInstruction}
    end,
    Config = build_generation_config(Opts),
    case maps:size(Config) of
        0 -> Base1;
        _ -> Base1#{generationConfig => Config}
    end.

build_generation_config(Opts) ->
    Config = #{},
    Config1 = case maps:get(temperature, Opts, undefined) of
        undefined -> Config;
        Temp -> Config#{temperature => Temp}
    end,
    case maps:get(max_tokens, Opts, undefined) of
        undefined -> Config1;
        MaxTokens -> Config1#{maxOutputTokens => MaxTokens}
    end.

normalize_model(#{<<"name">> := FullName} = M) ->
    %% Model names come as "models/gemini-1.5-pro" — strip prefix
    Name = case binary:split(FullName, <<"/">>) of
        [_, ShortName] -> ShortName;
        _ -> FullName
    end,
    %% Only include generative models
    SupportedMethods = maps:get(<<"supportedGenerationMethods">>, M, []),
    case lists:member(<<"generateContent">>, SupportedMethods) of
        true ->
            InputLimit = maps:get(<<"inputTokenLimit">>, M, 0),
            OutputLimit = maps:get(<<"outputTokenLimit">>, M, 0),
            {true, #{
                name => Name,
                context_length => InputLimit + OutputLimit,
                family => <<"gemini">>,
                parameter_size => <<>>,
                format => <<"api">>
            }};
        false ->
            false
    end;
normalize_model(_) ->
    false.

normalize_response(#{<<"candidates">> := [Candidate | _]} = Resp) ->
    Content = maps:get(<<"content">>, Candidate, #{}),
    Parts = maps:get(<<"parts">>, Content, []),
    Text = extract_text(Parts),
    Usage = maps:get(<<"usageMetadata">>, Resp, #{}),
    #{
        content => Text,
        model => <<>>,
        done => true,
        eval_count => maps:get(<<"candidatesTokenCount">>, Usage, 0),
        prompt_eval_count => maps:get(<<"promptTokenCount">>, Usage, 0),
        message => #{role => <<"assistant">>, content => Text}
    };
normalize_response(_) ->
    #{content => <<>>, done => true}.

extract_text([]) -> <<>>;
extract_text([#{<<"text">> := Text} | _]) -> Text;
extract_text([_ | Rest]) -> extract_text(Rest).

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
                process_sse_event(EventData, Ref, Caller)
            end, Events),
            stream_loop(ClientRef, Ref, Caller, Rest);
        {hackney_response, ClientRef, {error, Reason}} ->
            Caller ! {llm_error, Ref, Reason}
    after 120000 ->
        Caller ! {llm_error, Ref, timeout},
        hackney:close(ClientRef)
    end.

process_sse_event(Data, Ref, Caller) ->
    try json:decode(Data) of
        #{<<"candidates">> := [Candidate | _]} = Resp ->
            Content = maps:get(<<"content">>, Candidate, #{}),
            Parts = maps:get(<<"parts">>, Content, []),
            error_logger:info_msg("[GOOGLE DEBUG] Candidate=~p~nContent=~p~nParts=~p~n", [Candidate, Content, Parts]),
            Text = extract_text(Parts),
            FinishReason = maps:get(<<"finishReason">>, Candidate, null),
            Done = FinishReason =/= null,
            %% Use binary keys to match what hecate_api_llm expects
            ChunkMap = #{<<"content">> => Text, <<"done">> => Done},
            FinalChunk = case Done of
                true ->
                    Usage = maps:get(<<"usageMetadata">>, Resp, #{}),
                    ChunkMap#{
                        <<"eval_count">> => maps:get(<<"candidatesTokenCount">>, Usage, 0),
                        <<"prompt_eval_count">> => maps:get(<<"promptTokenCount">>, Usage, 0)
                    };
                false ->
                    ChunkMap
            end,
            Caller ! {llm_chunk, Ref, FinalChunk};
        _ ->
            ok
    catch _:_ ->
        ok
    end.

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
