%%% @doc Chat to LLM
%%% Executes chat completion against Ollama.
-module(chat_to_llm).

-export([chat/2, chat/3, chat_stream/3]).

-define(OLLAMA_URL, "http://localhost:11434").

%% Suppress dialyzer supertype warning (map() is intentionally general for API)
-dialyzer({nowarn_function, [chat/2, chat/3]}).

-spec chat(binary(), list()) -> {ok, map()} | {error, term()}.
chat(Model, Messages) ->
    chat(Model, Messages, #{}).

-spec chat(binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Model, Messages, Opts) ->
    BaseUrl = get_ollama_url(),
    Url = BaseUrl ++ "/api/chat",
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

%% @doc Start a streaming chat completion.
%% Returns {ok, Ref} where Ref is used to identify chunks.
%% The caller receives messages:
%%   {llm_chunk, Ref, ChunkMap} - for each chunk
%%   {llm_done, Ref} - when complete
%%   {llm_error, Ref, Reason} - on error
-spec chat_stream(string(), list(), map()) -> {ok, reference()}.
chat_stream(BaseUrl, Messages, Opts) ->
    Ref = make_ref(),
    Caller = self(),
    Model = maps:get(model, Opts, <<"llama3.2">>),
    spawn_link(fun() -> do_stream(BaseUrl, Model, Messages, Opts, Ref, Caller) end),
    {ok, Ref}.

do_stream(BaseUrl, Model, Messages, Opts, Ref, Caller) ->
    Url = BaseUrl ++ "/api/chat",
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
    end.

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
    %% Incomplete line, keep as buffer
    {lists:reverse(Acc), Last};
parse_lines([Line | Rest], Acc, _) ->
    case catch json:decode(Line) of
        {'EXIT', _} ->
            parse_lines(Rest, Acc, <<>>);
        Decoded ->
            parse_lines(Rest, [Decoded | Acc], <<>>)
    end.

get_ollama_url() ->
    case os:getenv("OLLAMA_HOST") of
        false -> application:get_env(serve_llm, ollama_url, ?OLLAMA_URL);
        Url -> Url
    end.
