%%% @doc LLM usage aggregate (append-only).
%%%
%%% Stream: llm_usage-{venture_id}
%%% Store: llm_store
%%%
%%% Trivial aggregate for append-only usage tracking.
%%% Execute always succeeds. State tracks call count only.
%%% @end
-module(llm_usage_aggregate).

-behaviour(evoq_aggregate).

-include("llm_usage_state.hrl").

-export([state_module/0, init/1, execute/2, apply/2]).

-type state() :: #llm_usage_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> llm_usage_state.

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, llm_usage_state:new(AggregateId)}.

%% Execute: always accept track_llm_call commands
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(_State, #{command_type := <<"track_llm_call">>} = Payload) ->
    {ok, Cmd} = track_llm_call_v1:from_map(Payload),
    case maybe_track_llm_call:handle(Cmd) of
        {ok, Events} ->
            {ok, [llm_call_tracked_v1:to_map(E) || E <- Events]};
        {error, _} = Err ->
            Err
    end;
execute(_State, _Payload) ->
    {error, unknown_command}.

%% Apply: delegate to state module
-spec apply(state(), map()) -> state().
apply(State, Event) ->
    llm_usage_state:apply_event(State, Event).

