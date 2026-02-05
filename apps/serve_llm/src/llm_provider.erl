%%% @doc LLM Provider Behaviour
%%%
%%% Defines the contract for all LLM providers (Ollama, OpenAI, Anthropic, Google).
%%% Each provider normalizes responses to a common internal format so that
%%% callers (API handlers, mesh responders) work identically regardless of backend.
%%%
%%% Streaming protocol:
%%%   The caller receives messages of the form:
%%%     {llm_chunk, Ref, #{content => binary(), done => boolean()}}
%%%     {llm_done, Ref}
%%%     {llm_error, Ref, Reason}
%%% @end
-module(llm_provider).

-export([provider_module/1]).

%% @doc List models available from this provider.
%% Returns normalized model maps: #{name, context_length, family, parameter_size}
-callback list_models(Config :: map()) ->
    {ok, [map()]} | {error, term()}.

%% @doc Synchronous chat completion.
%% Returns a normalized response map compatible with the existing API format.
-callback chat(Config :: map(), Model :: binary(), Messages :: list(), Opts :: map()) ->
    {ok, map()} | {error, term()}.

%% @doc Streaming chat completion.
%% Sends chunks to Caller as {llm_chunk, Ref, ChunkMap}, then {llm_done, Ref}.
%% On error sends {llm_error, Ref, Reason}.
-callback chat_stream(Config :: map(), Model :: binary(), Messages :: list(),
    Opts :: map(), Caller :: pid(), Ref :: reference()) -> ok.

%% @doc Health check - verify provider is reachable and configured correctly.
-callback health(Config :: map()) -> ok | {error, term()}.

%% @doc Map a provider type atom to its implementing module.
-spec provider_module(atom()) -> module().
provider_module(ollama) -> ollama_provider;
provider_module(openai) -> openai_provider;
provider_module(anthropic) -> anthropic_provider;
provider_module(google) -> google_provider.
