%%% @doc Report LLM Status
%%% Periodically checks each known model's availability and emits
%%% llm_status_reported_v1 events to serve_llm_store.
-module(report_llm_status).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [store_event/2]}).

-define(DEFAULT_STATUS_INTERVAL_MS, 30000). %% 30 seconds
-define(OLLAMA_URL, "http://localhost:11434").

-record(state, {
    timer_ref :: reference() | undefined,
    interval :: non_neg_integer(),
    ollama_url :: string()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Interval = application:get_env(serve_llm, status_interval_ms, ?DEFAULT_STATUS_INTERVAL_MS),
    OllamaUrl = application:get_env(serve_llm, ollama_url, ?OLLAMA_URL),
    %% Delay first check to let detect_llms populate models first
    TimerRef = erlang:send_after(Interval, self(), check_status),
    {ok, #state{
        timer_ref = TimerRef,
        interval = Interval,
        ollama_url = OllamaUrl
    }}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(check_status, #state{interval = Interval, ollama_url = Url} = State) ->
    check_and_report(Url),
    TimerRef = erlang:send_after(Interval, self(), check_status),
    {noreply, State#state{timer_ref = TimerRef}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = undefined}) -> ok;
terminate(_Reason, #state{timer_ref = TimerRef}) ->
    erlang:cancel_timer(TimerRef),
    ok.

%% Internal

check_and_report(BaseUrl) ->
    case fetch_running_models(BaseUrl) of
        {ok, RunningModels} ->
            RunningMap = running_models_to_map(RunningModels),
            %% Also get all available models
            case fetch_available_models(BaseUrl) of
                {ok, AllModels} ->
                    report_all_statuses(AllModels, RunningMap);
                {error, _} ->
                    %% Can't get model list, report running ones only
                    report_running_statuses(RunningMap)
            end;
        {error, _} ->
            ok
    end.

fetch_running_models(BaseUrl) ->
    Url = BaseUrl ++ "/api/ps",
    case hackney:get(Url, [], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            #{<<"models">> := Models} = json:decode(Body),
            {ok, Models};
        {ok, _Status, _Headers, _Body} ->
            {error, not_available};
        {error, Reason} ->
            {error, Reason}
    end.

fetch_available_models(BaseUrl) ->
    Url = BaseUrl ++ "/api/tags",
    case hackney:get(Url, [], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            #{<<"models">> := Models} = json:decode(Body),
            {ok, Models};
        {ok, _Status, _Headers, _Body} ->
            {error, not_available};
        {error, Reason} ->
            {error, Reason}
    end.

running_models_to_map(Models) ->
    lists:foldl(fun(Model, Acc) ->
        Name = maps:get(<<"name">>, Model, <<"unknown">>),
        Acc#{Name => Model}
    end, #{}, Models).

report_all_statuses(AllModels, RunningMap) ->
    lists:foreach(fun(Model) ->
        Name = maps:get(<<"name">>, Model, <<"unknown">>),
        IsRunning = maps:is_key(Name, RunningMap),
        Status = build_status(Name, IsRunning, RunningMap),
        emit_status(Name, Status)
    end, AllModels).

report_running_statuses(RunningMap) ->
    maps:foreach(fun(Name, _RunInfo) ->
        Status = build_status(Name, true, RunningMap),
        emit_status(Name, Status)
    end, RunningMap).

build_status(Name, IsRunning, RunningMap) ->
    Base = #{
        available => IsRunning,
        queue_depth => 0,
        avg_tokens_per_sec => 0.0
    },
    case maps:get(Name, RunningMap, undefined) of
        undefined ->
            Base;
        RunInfo ->
            %% Extract details from running model info if available
            Details = maps:get(<<"details">>, RunInfo, #{}),
            Base#{
                size_vram => maps:get(<<"size_vram">>, RunInfo, 0),
                size => maps:get(<<"size">>, RunInfo, 0),
                quantization => maps:get(<<"quantization_level">>, Details, <<"unknown">>)
            }
    end.

emit_status(ModelName, Status) ->
    {ok, Event} = llm_status_reported_v1:new(ModelName, Status),
    store_event(<<"llm_status_reported_v1">>, llm_status_reported_v1:to_map(Event)).

store_event(EventType, EventData) ->
    Event = EventData#{event_type => EventType},
    reckon_evoq_adapter:append(serve_llm_store, <<"llm_status">>, ?ANY_VERSION, [Event]).
