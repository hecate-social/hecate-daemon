%%% @doc Provider Registry
%%%
%%% Manages LLM provider configurations. Persists to data/providers.json.
%%% Ollama is always present as the default provider.
%%%
%%% Provides model-to-provider resolution with a cached mapping (TTL-based).
%%% @end
-module(manage_providers).
-behaviour(gen_server).

-export([start_link/0]).
-export([list/0, add/3, remove/1, provider_for_model/1, list_all_models/0, refresh_models/0, reload/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(PROVIDERS_FILE, "data/providers.json").
-define(MODEL_CACHE_TTL_MS, 300000). %% 5 minutes

-record(state, {
    providers :: #{binary() => map()},
    model_cache :: #{binary() => {module(), map()}},
    models_meta :: [map()],  %% full model info for listing endpoint
    cache_updated_at :: non_neg_integer()
}).

%%% ===================================================================
%%% Public API
%%% ===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc List all configured providers.
-spec list() -> #{binary() => map()}.
list() ->
    gen_server:call(?SERVER, list).

%% @doc Add a provider configuration.
%% Name is a user-chosen label, Type is the provider atom (ollama, openai, anthropic, google),
%% Config contains provider-specific settings (url, api_key, etc).
-spec add(binary(), atom(), map()) -> ok | {error, term()}.
add(Name, Type, Config) ->
    gen_server:call(?SERVER, {add, Name, Type, Config}).

%% @doc Remove a provider by name.
-spec remove(binary()) -> ok | {error, term()}.
remove(Name) ->
    gen_server:call(?SERVER, {remove, Name}).

%% @doc Find which provider serves a given model.
%% Returns {Module, Config} or {error, not_found}.
-spec provider_for_model(binary()) -> {module(), map()} | {error, not_found}.
provider_for_model(Model) ->
    gen_server:call(?SERVER, {provider_for_model, Model}, 30000).

%% @doc List all validated models from cache with provider info.
%% Returns models that passed validation (probe) during cache build.
-spec list_all_models() -> {ok, [map()]}.
list_all_models() ->
    gen_server:call(?SERVER, list_all_models, 30000).

%% @doc Force refresh of the model cache.
-spec refresh_models() -> ok.
refresh_models() ->
    gen_server:cast(?SERVER, refresh_models).

%% @doc Reload providers from disk and re-detect from environment variables.
%% Useful for picking up new API keys without restarting the daemon.
-spec reload() -> ok.
reload() ->
    gen_server:call(?SERVER, reload).

%%% ===================================================================
%%% gen_server callbacks
%%% ===================================================================

init([]) ->
    Providers = load_providers(),
    %% Auto-detect providers from environment variables
    ProvidersWithEnv = auto_detect_env_providers(Providers),
    {ok, #state{
        providers = ProvidersWithEnv,
        model_cache = #{},
        models_meta = [],
        cache_updated_at = 0
    }}.

handle_call(list, _From, #state{providers = Providers} = State) ->
    {reply, Providers, State};

handle_call(reload, _From, _State) ->
    Providers = load_providers(),
    ProvidersWithEnv = auto_detect_env_providers(Providers),
    NewState = #state{
        providers = ProvidersWithEnv,
        model_cache = #{},
        models_meta = [],
        cache_updated_at = 0
    },
    {reply, ok, NewState};

handle_call({add, Name, Type, Config}, _From, #state{providers = Providers} = State) ->
    ProviderConfig = Config#{type => Type, enabled => true},
    NewProviders = Providers#{Name => ProviderConfig},
    persist_providers(NewProviders),
    %% Invalidate model cache when providers change
    {reply, ok, State#state{providers = NewProviders, model_cache = #{}, models_meta = [], cache_updated_at = 0}};

handle_call({remove, <<"ollama">>}, _From, State) ->
    {reply, {error, cannot_remove_default}, State};
handle_call({remove, Name}, _From, #state{providers = Providers} = State) ->
    case maps:is_key(Name, Providers) of
        true ->
            NewProviders = maps:remove(Name, Providers),
            persist_providers(NewProviders),
            {reply, ok, State#state{providers = NewProviders, model_cache = #{}, models_meta = [], cache_updated_at = 0}};
        false ->
            {reply, {error, not_found}, State}
    end;

handle_call({provider_for_model, Model}, _From, State) ->
    {Result, NewState} = resolve_model(Model, State),
    {reply, Result, NewState};

handle_call(list_all_models, _From, State) ->
    {_Cache, NewState} = ensure_cache(State),
    {reply, {ok, NewState#state.models_meta}, NewState};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(refresh_models, State) ->
    {noreply, State#state{model_cache = #{}, models_meta = [], cache_updated_at = 0}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%% ===================================================================
%%% Internal
%%% ===================================================================

resolve_model(Model, State) ->
    {Cache, NewState} = ensure_cache(State),
    Result = maps:get(Model, Cache, {error, not_found}),
    {Result, NewState}.

ensure_cache(#state{model_cache = Cache, cache_updated_at = CacheTime} = State) ->
    Now = erlang:system_time(millisecond),
    CacheExpired = (Now - CacheTime) > ?MODEL_CACHE_TTL_MS,
    case {map_size(Cache), CacheExpired} of
        {0, _} ->
            rebuild_cache(State, Now);
        {_, true} ->
            rebuild_cache(State, Now);
        _ ->
            {Cache, State}
    end.

rebuild_cache(State, Now) ->
    {NewCache, Meta} = build_model_cache(State#state.providers),
    NewState = State#state{model_cache = NewCache, models_meta = Meta, cache_updated_at = Now},
    {NewCache, NewState}.

build_model_cache(Providers) ->
    maps:fold(fun(ProviderName, #{type := Type, enabled := true} = Config, {CacheAcc, MetaAcc}) ->
        Mod = llm_provider:provider_module(Type),
        case Mod:list_models(Config) of
            {ok, Models} ->
                Validated = validate_models(Mod, Config, Models),
                ProviderConfig = Config#{provider_name => ProviderName},
                NewCache = lists:foldl(fun(#{name := ModelName}, InnerAcc) ->
                    case maps:is_key(ModelName, InnerAcc) of
                        true -> InnerAcc;
                        false -> InnerAcc#{ModelName => {Mod, ProviderConfig}}
                    end
                end, CacheAcc, Validated),
                NewMeta = [M#{provider => ProviderName} || M <- Validated],
                {NewCache, MetaAcc ++ NewMeta};
            {error, Reason} ->
                logger:warning("[manage_providers] Failed to list models for ~s: ~p",
                    [ProviderName, Reason]),
                {CacheAcc, MetaAcc}
        end;
    (_ProviderName, _DisabledConfig, Acc) ->
        Acc
    end, {#{}, []}, Providers).

validate_models(Mod, Config, Models) ->
    case erlang:function_exported(Mod, probe_model, 2) of
        true ->
            lists:filter(fun(#{name := Name}) ->
                case Mod:probe_model(Config, Name) of
                    ok ->
                        true;
                    {error, unauthorized} ->
                        %% Bad API key — don't probe further, keep model in list
                        %% so user sees it and can fix their key
                        logger:warning("[manage_providers] Probe ~s: unauthorized (bad API key?)", [Name]),
                        true;
                    {error, Reason} ->
                        logger:info("[manage_providers] Model ~s failed probe, excluding: ~p", [Name, Reason]),
                        false
                end
            end, Models);
        false ->
            Models
    end.

load_providers() ->
    case file:read_file(?PROVIDERS_FILE) of
        {ok, Data} ->
            try
                Decoded = json:decode(Data),
                normalize_loaded_providers(Decoded)
            catch _:_ ->
                default_providers()
            end;
        {error, _} ->
            default_providers()
    end.

normalize_loaded_providers(Map) when is_map(Map) ->
    Normalized = maps:map(fun(_Name, Config) ->
        Type = case maps:get(<<"type">>, Config, maps:get(type, Config, <<"ollama">>)) of
            B when is_binary(B) -> binary_to_existing_atom(B, utf8);
            A when is_atom(A) -> A
        end,
        Url = maps:get(<<"url">>, Config, maps:get(url, Config, <<>>)),
        ApiKey = maps:get(<<"api_key">>, Config, maps:get(api_key, Config, <<>>)),
        Enabled = maps:get(<<"enabled">>, Config, maps:get(enabled, Config, true)),
        Base = #{type => Type, enabled => Enabled},
        Base1 = case Url of
            <<>> -> Base;
            _ -> Base#{url => binary_to_list(Url)}
        end,
        case ApiKey of
            <<>> -> Base1;
            _ -> Base1#{api_key => ApiKey}
        end
    end, Map),
    %% Ensure ollama is always present
    case maps:is_key(<<"ollama">>, Normalized) of
        true -> Normalized;
        false -> Normalized#{<<"ollama">> => default_ollama_config()}
    end;
normalize_loaded_providers(_) ->
    default_providers().

persist_providers(Providers) ->
    %% Convert to JSON-friendly format
    JsonMap = maps:map(fun(_Name, Config) ->
        Type = maps:get(type, Config, ollama),
        Base = #{<<"type">> => atom_to_binary(Type, utf8),
                 <<"enabled">> => maps:get(enabled, Config, true)},
        Base1 = case maps:get(url, Config, undefined) of
            undefined -> Base;
            Url when is_list(Url) -> Base#{<<"url">> => list_to_binary(Url)};
            Url -> Base#{<<"url">> => Url}
        end,
        case maps:get(api_key, Config, undefined) of
            undefined -> Base1;
            Key -> Base1#{<<"api_key">> => Key}
        end
    end, Providers),
    Data = json:encode(JsonMap),
    filelib:ensure_dir(?PROVIDERS_FILE),
    file:write_file(?PROVIDERS_FILE, Data).

default_providers() ->
    #{<<"ollama">> => default_ollama_config()}.

default_ollama_config() ->
    Url = case os:getenv("OLLAMA_HOST") of
        false -> application:get_env(serve_llm, ollama_url, "http://localhost:11434");
        EnvUrl -> EnvUrl
    end,
    #{type => ollama, url => Url, enabled => true}.

%% @doc Auto-detect providers from environment variables.
%% Checks for OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY/GEMINI_API_KEY, GROQ_API_KEY.
%% Only adds providers not already configured.
auto_detect_env_providers(Providers) ->
    %% Resolve Google/Gemini key: prefer GOOGLE_API_KEY, fall back to GEMINI_API_KEY
    GoogleEnvVar = case os:getenv("GOOGLE_API_KEY") of
        false -> "GEMINI_API_KEY";
        _ -> "GOOGLE_API_KEY"
    end,
    EnvProviders = [
        {<<"openai">>, "OPENAI_API_KEY", openai, "https://api.openai.com"},
        {<<"anthropic">>, "ANTHROPIC_API_KEY", anthropic, "https://api.anthropic.com"},
        {<<"google">>, GoogleEnvVar, google, "https://generativelanguage.googleapis.com"},
        %% Groq uses OpenAI-compatible API with function calling support
        {<<"groq">>, "GROQ_API_KEY", openai, "https://api.groq.com/openai"}
    ],
    lists:foldl(fun({Name, EnvVar, Type, Url}, Acc) ->
        case {maps:is_key(Name, Acc), os:getenv(EnvVar)} of
            {true, _} ->
                %% Already configured, skip
                Acc;
            {false, false} ->
                %% Env var not set, skip
                Acc;
            {false, ApiKey} ->
                %% Env var set, add provider
                logger:info("[manage_providers] Auto-detected ~s from ~s", [Name, EnvVar]),
                Acc#{Name => #{
                    type => Type,
                    url => Url,
                    api_key => list_to_binary(ApiKey),
                    enabled => true
                }}
        end
    end, Providers, EnvProviders).
