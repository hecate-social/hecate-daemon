%%% @doc Detect LLMs
%%% Polls Ollama for available models on startup and periodically.
%%% Emits llm_detected_v1 and llm_removed_v1 events.
-module(detect_llms).
-behaviour(gen_server).

-export([start_link/0, poll_now/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [store_event/2]}).

-define(DEFAULT_POLL_INTERVAL_MS, 300000). %% 5 minutes
-define(OLLAMA_URL, "http://localhost:11434").

-record(state, {
    known_models :: #{binary() => map()},
    timer_ref :: reference() | undefined,
    poll_interval :: non_neg_integer(),
    ollama_url :: string()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

poll_now() ->
    gen_server:cast(?MODULE, poll_now).

init([]) ->
    PollInterval = application:get_env(serve_llm, poll_interval_ms, ?DEFAULT_POLL_INTERVAL_MS),
    OllamaUrl = application:get_env(serve_llm, ollama_url, ?OLLAMA_URL),
    self() ! poll,
    {ok, #state{
        known_models = #{},
        timer_ref = undefined,
        poll_interval = PollInterval,
        ollama_url = OllamaUrl
    }}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(poll_now, State) ->
    {noreply, do_poll(State)};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(poll, #state{poll_interval = Interval} = State) ->
    NewState = do_poll(State),
    TimerRef = erlang:send_after(Interval, self(), poll),
    {noreply, NewState#state{timer_ref = TimerRef}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = undefined}) -> ok;
terminate(_Reason, #state{timer_ref = TimerRef}) ->
    erlang:cancel_timer(TimerRef),
    ok.

%% Internal

do_poll(#state{known_models = KnownModels, ollama_url = Url} = State) ->
    case fetch_models(Url) of
        {ok, CurrentModels} ->
            CurrentMap = models_to_map(CurrentModels),
            NewModels = maps:without(maps:keys(KnownModels), CurrentMap),
            RemovedNames = maps:keys(KnownModels) -- maps:keys(CurrentMap),

            maps:foreach(fun(Name, Info) ->
                emit_detected(Name, Info)
            end, NewModels),

            lists:foreach(fun(Name) ->
                emit_removed(Name)
            end, RemovedNames),

            State#state{known_models = CurrentMap};
        {error, _Reason} ->
            State
    end.

fetch_models(BaseUrl) ->
    Url = BaseUrl ++ "/api/tags",
    case hackney:get(Url, [], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            #{<<"models">> := Models} = json:decode(Body),
            {ok, Models};
        {ok, Status, _Headers, _Body} ->
            {error, {http_status, Status}};
        {error, Reason} ->
            {error, Reason}
    end.

models_to_map(Models) ->
    lists:foldl(fun(Model, Acc) ->
        Name = maps:get(<<"name">>, Model, <<"unknown">>),
        Acc#{Name => Model}
    end, #{}, Models).

emit_detected(ModelName, OllamaInfo) ->
    {ok, Event} = llm_detected_v1:new(ModelName, build_model_info(ModelName, OllamaInfo)),
    store_event(<<"llm_detected_v1">>, llm_detected_v1:to_map(Event)).

emit_removed(ModelName) ->
    {ok, Event} = llm_removed_v1:new(ModelName),
    store_event(<<"llm_removed_v1">>, llm_removed_v1:to_map(Event)).

store_event(EventType, EventData) ->
    reckon_evoq_adapter:append(serve_llm_store, <<"llms">>, EventType, EventData, #{}).

build_model_info(ModelName, OllamaInfo) ->
    Details = maps:get(<<"details">>, OllamaInfo, #{}),
    #{
        name => ModelName,
        context_length => maps:get(<<"context_length">>, Details, 4096),
        quantization => maps:get(<<"quantization_level">>, Details, <<"unknown">>),
        parameter_count => maps:get(<<"parameter_size">>, Details, <<"unknown">>),
        family => maps:get(<<"family">>, Details, <<"unknown">>),
        size_bytes => maps:get(<<"size">>, OllamaInfo, 0)
    }.
