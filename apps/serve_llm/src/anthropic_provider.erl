%%% @doc Anthropic LLM Provider
%%%
%%% Implements llm_provider behaviour for the Anthropic Messages API (Claude models).
%%% @end
-module(anthropic_provider).
-behaviour(llm_provider).

-export([list_models/1, chat/4, chat_stream/6, health/1]).
-export([probe_model/2]).

-define(API_VERSION, <<"2023-06-01">>).

%%% ===================================================================
%%% llm_provider callbacks
%%% ===================================================================

-spec list_models(map()) -> {ok, [map()]} | {error, term()}.
list_models(_Config) ->
    %% Anthropic does not have a public list-models endpoint.
    %% Return known production models. These are validated via probe_model/2
    %% during cache build in manage_providers so stale IDs are filtered out.
    {ok, [
        #{name => <<"claude-opus-4-6">>,
          context_length => 200000, family => <<"claude">>,
          parameter_size => <<>>, format => <<"api">>},
        #{name => <<"claude-sonnet-4-6">>,
          context_length => 200000, family => <<"claude">>,
          parameter_size => <<>>, format => <<"api">>},
        #{name => <<"claude-haiku-4-5-20251001">>,
          context_length => 200000, family => <<"claude">>,
          parameter_size => <<>>, format => <<"api">>}
    ]}.

-spec chat(map(), binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Config, Model, Messages, Opts) ->
    Url = base_url(Config) ++ "/v1/messages",
    Headers = request_headers(Config),
    {System, UserMessages} = extract_system(Messages),
    Body = json:encode(build_request(Model, System, UserMessages, Opts, false)),
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
    Url = base_url(Config) ++ "/v1/messages",
    Headers = request_headers(Config),
    {System, UserMessages} = extract_system(Messages),
    Body = json:encode(build_request(Model, System, UserMessages, Opts, true)),
    case hackney:post(Url, Headers, Body, [async]) of
        {ok, ClientRef} ->
            stream_loop(ClientRef, Ref, Caller, <<>>);
        {error, Reason} ->
            Caller ! {llm_error, Ref, Reason}
    end,
    ok.

-spec health(map()) -> ok | {error, term()}.
health(Config) ->
    %% Anthropic has no lightweight health endpoint;
    %% send a minimal request to validate the API key.
    Url = base_url(Config) ++ "/v1/messages",
    Headers = request_headers(Config),
    Body = json:encode(#{
        model => <<"claude-haiku-4-5-20251001">>,
        max_tokens => 1,
        messages => [#{role => <<"user">>, content => <<"hi">>}]
    }),
    case hackney:post(Url, Headers, Body, [with_body, {recv_timeout, 10000}]) of
        {ok, 200, _Headers, _Body} -> ok;
        {ok, 401, _Headers, _Body} -> {error, unauthorized};
        {ok, Status, _Headers, _Body} -> {error, {http_status, Status}};
        {error, Reason} -> {error, Reason}
    end.

%% @doc Probe whether a model ID is accepted by the Anthropic API.
%% Sends a minimal request (max_tokens=1). Returns ok if the model is valid
%% (200 or 529/overloaded), {error, Reason} if the model ID is rejected (400/404).
-spec probe_model(map(), binary()) -> ok | {error, term()}.
probe_model(Config, Model) ->
    Url = base_url(Config) ++ "/v1/messages",
    Headers = request_headers(Config),
    Body = json:encode(#{
        model => Model,
        max_tokens => 1,
        messages => [#{role => <<"user">>, content => <<"hi">>}]
    }),
    case hackney:post(Url, Headers, Body, [with_body, {recv_timeout, 10000}]) of
        {ok, 200, _H, _B} -> ok;
        {ok, 529, _H, _B} -> ok;  %% overloaded but model is valid
        {ok, 400, _H, RespBody} -> {error, {invalid_model, RespBody}};
        {ok, 404, _H, _B} -> {error, model_not_found};
        {ok, 401, _H, _B} -> {error, unauthorized};
        {ok, Status, _H, _B} -> {error, {http_status, Status}};
        {error, Reason} -> {error, Reason}
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

base_url(#{url := Url}) when is_list(Url) -> Url;
base_url(#{url := Url}) when is_binary(Url) -> binary_to_list(Url);
base_url(_) -> "https://api.anthropic.com".

request_headers(Config) ->
    ApiKey = maps:get(api_key, Config, <<>>),
    [
        {<<"Content-Type">>, <<"application/json">>},
        {<<"x-api-key">>, ApiKey},
        {<<"anthropic-version">>, ?API_VERSION}
    ].

%% @doc Extract system message from the message list.
%% Anthropic expects system as a separate top-level field.
extract_system(Messages) ->
    extract_system(Messages, <<>>, []).

extract_system([], System, Acc) ->
    {System, lists:reverse(Acc)};
extract_system([#{role := <<"system">>} = M | Rest], _System, Acc) ->
    extract_system(Rest, maps:get(content, M, <<>>), Acc);
extract_system([#{<<"role">> := <<"system">>} = M | Rest], _System, Acc) ->
    extract_system(Rest, maps:get(<<"content">>, M, <<>>), Acc);
extract_system([M | Rest], System, Acc) ->
    extract_system(Rest, System, [M | Acc]).

build_request(Model, System, Messages, Opts, Stream) ->
    MaxTokens = maps:get(max_tokens, Opts, 4096),
    Base = #{
        model => Model,
        messages => Messages,
        max_tokens => MaxTokens
    },
    Base1 = case System of
        <<>> -> Base;
        _ -> Base#{system => System}
    end,
    Base2 = case Stream of
        true -> Base1#{stream => true};
        false -> Base1
    end,
    Base3 = case maps:get(temperature, Opts, undefined) of
        undefined -> Base2;
        Temp -> Base2#{temperature => Temp}
    end,
    %% Add tools if provided
    case maps:get(tools, Opts, undefined) of
        undefined -> Base3;
        [] -> Base3;
        Tools when is_list(Tools) ->
            ToolSchemas = [tool_to_anthropic_schema(T) || T <- Tools],
            Base3#{tools => ToolSchemas}
    end.

%% @doc Convert tool definition to Anthropic's schema format.
tool_to_anthropic_schema(#{name := Name, description := Desc, input_schema := Schema}) ->
    #{
        name => Name,
        description => Desc,
        input_schema => Schema
    };
tool_to_anthropic_schema(#{<<"name">> := Name, <<"description">> := Desc, <<"input_schema">> := Schema}) ->
    #{
        name => Name,
        description => Desc,
        input_schema => Schema
    }.

normalize_response(#{<<"content">> := Content} = Resp) when is_list(Content) ->
    Text = extract_text(Content),
    ToolCalls = extract_tool_calls(Content),
    StopReason = maps:get(<<"stop_reason">>, Resp, <<>>),
    Usage = maps:get(<<"usage">>, Resp, #{}),
    BaseResp = #{
        content => Text,
        model => maps:get(<<"model">>, Resp, <<>>),
        done => true,
        stop_reason => StopReason,
        eval_count => maps:get(<<"output_tokens">>, Usage, 0),
        prompt_eval_count => maps:get(<<"input_tokens">>, Usage, 0),
        message => #{role => <<"assistant">>, content => Text}
    },
    case ToolCalls of
        [] -> BaseResp;
        _ -> BaseResp#{tool_calls => ToolCalls}
    end;
normalize_response(_) ->
    #{content => <<>>, done => true}.

extract_text([]) -> <<>>;
extract_text([#{<<"type">> := <<"text">>, <<"text">> := Text} | _]) -> Text;
extract_text([_ | Rest]) -> extract_text(Rest).

extract_tool_calls(Content) ->
    [#{
        id => maps:get(<<"id">>, Block, <<>>),
        name => maps:get(<<"name">>, Block, <<>>),
        arguments => maps:get(<<"input">>, Block, #{})
    } || Block <- Content, maps:get(<<"type">>, Block, <<>>) =:= <<"tool_use">>].

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
        %% Text content delta
        #{<<"type">> := <<"content_block_delta">>,
          <<"delta">> := #{<<"type">> := <<"text_delta">>, <<"text">> := Text}} ->
            %% Use binary keys to match what hecate_api_llm expects
            Caller ! {llm_chunk, Ref, #{<<"content">> => Text, <<"done">> => false}};

        %% Tool use input delta (accumulates JSON)
        #{<<"type">> := <<"content_block_delta">>,
          <<"delta">> := #{<<"type">> := <<"input_json_delta">>, <<"partial_json">> := PartialJson}} ->
            Caller ! {llm_tool_input_delta, Ref, PartialJson};

        %% Tool use block start - LLM wants to use a tool
        #{<<"type">> := <<"content_block_start">>,
          <<"content_block">> := #{<<"type">> := <<"tool_use">>, <<"id">> := Id, <<"name">> := Name}} ->
            Caller ! {llm_tool_use_start, Ref, #{id => Id, name => Name, input => <<>>}};

        %% Content block stop (might be text or tool)
        #{<<"type">> := <<"content_block_stop">>} ->
            Caller ! {llm_content_block_stop, Ref};

        %% Message delta with stop reason
        #{<<"type">> := <<"message_delta">>,
          <<"delta">> := #{<<"stop_reason">> := StopReason}} = Msg ->
            Usage = maps:get(<<"usage">>, Msg, #{}),
            %% Use binary keys to match what hecate_api_llm expects
            Caller ! {llm_chunk, Ref, #{
                <<"content">> => <<>>,
                <<"done">> => true,
                <<"stop_reason">> => StopReason,
                <<"eval_count">> => maps:get(<<"output_tokens">>, Usage, 0)
            }};

        %% Message stop
        #{<<"type">> := <<"message_stop">>} ->
            Caller ! {llm_done, Ref};

        %% Error
        #{<<"type">> := <<"error">>, <<"error">> := #{<<"message">> := ErrMsg}} ->
            Caller ! {llm_error, Ref, ErrMsg};

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
