%%% @doc LLM Model Poller
%%% Polls Ollama for available models on startup and periodically.
%%% Announces new models and retracts removed models.
-module(llm_model_poller).
-behaviour(gen_server).

-export([start_link/0, poll_now/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to llm_backend (pattern matching on returns)
-dialyzer({nowarn_function, [do_poll/1, announce_model/3, retract_model/2]}).

-define(POLL_INTERVAL_MS, 300000). %% 5 minutes

-record(state, {
    known_models :: #{binary() => map()},  %% model_name => model_info
    agent_identity :: binary(),
    timer_ref :: reference() | undefined
}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Force an immediate poll (for testing or manual refresh)
-spec poll_now() -> ok.
poll_now() ->
    gen_server:cast(?MODULE, poll_now).

%% Callbacks

init([]) ->
    AgentIdentity = get_agent_identity(),
    logger:info("[llm_model_poller] Starting with identity: ~s", [AgentIdentity]),
    %% Poll immediately on startup
    self() ! poll,
    {ok, #state{
        known_models = #{},
        agent_identity = AgentIdentity,
        timer_ref = undefined
    }}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(poll_now, State) ->
    {noreply, do_poll(State)};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(poll, State) ->
    NewState = do_poll(State),
    %% Schedule next poll
    TimerRef = erlang:send_after(?POLL_INTERVAL_MS, self(), poll),
    {noreply, NewState#state{timer_ref = TimerRef}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = undefined}) ->
    ok;
terminate(_Reason, #state{timer_ref = TimerRef}) ->
    erlang:cancel_timer(TimerRef),
    ok.

%% Internal

do_poll(#state{known_models = KnownModels, agent_identity = AgentID} = State) ->
    case llm_backend:list_models() of
        {ok, CurrentModels} ->
            CurrentMap = models_to_map(CurrentModels),

            %% Find new models (in current but not known)
            NewModels = maps:without(maps:keys(KnownModels), CurrentMap),

            %% Find removed models (in known but not current)
            RemovedModelNames = maps:keys(KnownModels) -- maps:keys(CurrentMap),
            RemovedModels = maps:with(RemovedModelNames, KnownModels),

            %% Announce new models
            maps:foreach(fun(Name, Info) ->
                announce_model(Name, Info, AgentID)
            end, NewModels),

            %% Retract removed models
            maps:foreach(fun(Name, _Info) ->
                retract_model(Name, AgentID)
            end, RemovedModels),

            %% Log summary
            log_poll_summary(maps:size(NewModels), maps:size(RemovedModels), maps:size(CurrentMap)),

            State#state{known_models = CurrentMap};

        {error, Reason} ->
            logger:warning("[llm_model_poller] Failed to list models: ~p", [Reason]),
            State
    end.

models_to_map(Models) ->
    lists:foldl(fun(Model, Acc) ->
        Name = maps:get(<<"name">>, Model, <<"unknown">>),
        Acc#{Name => Model}
    end, #{}, Models).

announce_model(ModelName, ModelInfo, AgentID) ->
    %% Extract model metadata
    Size = maps:get(<<"size">>, ModelInfo, 0),
    Details = maps:get(<<"details">>, ModelInfo, #{}),
    Quantization = maps:get(<<"quantization_level">>, Details, <<"unknown">>),
    ContextLength = maps:get(<<"context_length">>, Details, 4096),

    case announce_llm_capability_v1:new(#{
        model_name => ModelName,
        agent_identity => AgentID,
        model_size => Size,
        quantization => ensure_binary(Quantization),
        context_length => ContextLength,
        metadata => #{
            family => maps:get(<<"family">>, Details, <<"unknown">>),
            parameter_size => maps:get(<<"parameter_size">>, Details, <<"unknown">>)
        }
    }) of
        {ok, Cmd} ->
            case maybe_announce_llm_capability:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("[llm_model_poller] Announced model: ~s", [ModelName]);
                {error, Reason} ->
                    logger:warning("[llm_model_poller] Failed to announce ~s: ~p", [ModelName, Reason])
            end;
        {error, Reason} ->
            logger:warning("[llm_model_poller] Invalid command for ~s: ~p", [ModelName, Reason])
    end.

retract_model(ModelName, AgentID) ->
    case retract_llm_capability_v1:new(#{
        model_name => ModelName,
        agent_identity => AgentID,
        reason => <<"model_removed">>
    }) of
        {ok, Cmd} ->
            case maybe_retract_llm_capability:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("[llm_model_poller] Retracted model: ~s", [ModelName]);
                {error, Reason} ->
                    logger:warning("[llm_model_poller] Failed to retract ~s: ~p", [ModelName, Reason])
            end;
        {error, Reason} ->
            logger:warning("[llm_model_poller] Invalid retract command for ~s: ~p", [ModelName, Reason])
    end.

log_poll_summary(0, 0, Total) ->
    logger:debug("[llm_model_poller] Poll complete, ~p models (no changes)", [Total]);
log_poll_summary(New, Removed, Total) ->
    logger:info("[llm_model_poller] Poll complete: ~p models (+~p, -~p)", [Total, New, Removed]).

get_agent_identity() ->
    case application:get_env(hecate, gateway_identity) of
        {ok, Identity} -> ensure_binary(Identity);
        undefined -> <<"mri:agent:io.macula/hecate">>
    end.

ensure_binary(V) when is_binary(V) -> V;
ensure_binary(V) when is_list(V) -> list_to_binary(V);
ensure_binary(V) when is_atom(V) -> atom_to_binary(V, utf8);
ensure_binary(_) -> <<"unknown">>.
