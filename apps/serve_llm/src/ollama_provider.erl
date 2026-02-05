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
    Body = json:encode(#{
        model => Model,
        messages => Messages,
        stream => false,
        options => maps:get(options, Opts, #{})
    }),
    Headers = [{<<"Content-Type">>, <<"application/json">>}],
    case hackney:post(Url, Headers, Body, [with_body]) of
        {ok, 200, _RespHeaders, RespBody} ->
            {ok, json:decode(RespBody)};
        {ok, Status, _RespHeaders, RespBody} ->
            {error, {http_error, Status, RespBody}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec chat_stream(map(), binary(), list(), map(), pid(), reference()) -> ok.
chat_stream(Config, Model, Messages, Opts, Caller, Ref) ->
    Url = base_url(Config) ++ "/api/chat",
    Body = json:encode(#{
        model => Model,
        messages => Messages,
        stream => true,
        options => maps:get(options, Opts, #{})
    }),
    Headers = [{<<"Content-Type">>, <<"application/json">>}],
    case hackney:post(Url, Headers, Body, [async]) of
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
                Caller ! {llm_chunk, Ref, ChunkMap}
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
