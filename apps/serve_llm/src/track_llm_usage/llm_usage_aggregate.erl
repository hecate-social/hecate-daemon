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

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).

-record(llm_usage_state, {
    call_count = 0 :: non_neg_integer()
}).

-type state() :: #llm_usage_state{}.
-export_type([state/0]).

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #llm_usage_state{}.

%% Execute: always accept track_llm_call commands
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(_State, #{<<"command_type">> := <<"track_llm_call">>} = Payload) ->
    {ok, Cmd} = track_llm_call_v1:from_map(Payload),
    case maybe_track_llm_call:handle(Cmd) of
        {ok, Events} ->
            {ok, [llm_call_tracked_v1:to_map(E) || E <- Events]};
        {error, _} = Err ->
            Err
    end;
execute(_State, _Payload) ->
    {error, unknown_command}.

%% Apply: increment call count
-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().
apply_event(#{<<"event_type">> := <<"llm_call_tracked_v1">>}, #llm_usage_state{call_count = N} = S) ->
    S#llm_usage_state{call_count = N + 1};
apply_event(#{event_type := <<"llm_call_tracked_v1">>}, #llm_usage_state{call_count = N} = S) ->
    S#llm_usage_state{call_count = N + 1};
apply_event(_, S) ->
    S.
