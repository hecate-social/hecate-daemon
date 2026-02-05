%%% @doc Chat to LLM
%%% Dispatches chat completion to the appropriate provider via manage_providers.
-module(chat_to_llm).

-export([chat/2, chat/3, chat_stream/3]).

%% Suppress dialyzer supertype warning (map() is intentionally general for API)
-dialyzer({nowarn_function, [chat/2, chat/3]}).

-spec chat(binary(), list()) -> {ok, map()} | {error, term()}.
chat(Model, Messages) ->
    chat(Model, Messages, #{}).

-spec chat(binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Model, Messages, Opts) ->
    case manage_providers:provider_for_model(Model) of
        {error, not_found} ->
            {error, {unknown_model, Model}};
        {Mod, Config} ->
            Mod:chat(Config, Model, Messages, Opts)
    end.

%% @doc Start a streaming chat completion.
%% Returns {ok, Ref} where Ref is used to identify chunks.
%% The caller receives messages:
%%   {llm_chunk, Ref, ChunkMap} - for each chunk
%%   {llm_done, Ref} - when complete
%%   {llm_error, Ref, Reason} - on error
-spec chat_stream(binary(), list(), map()) -> {ok, reference()} | {error, term()}.
chat_stream(Model, Messages, Opts) ->
    case manage_providers:provider_for_model(Model) of
        {error, not_found} ->
            {error, {unknown_model, Model}};
        {Mod, Config} ->
            Ref = make_ref(),
            Caller = self(),
            spawn_link(fun() -> Mod:chat_stream(Config, Model, Messages, Opts, Caller, Ref) end),
            {ok, Ref}
    end.
