%%% @doc llm_call_tracked_v1 event
%%% Emitted when an LLM API call is recorded with cost data.
-module(llm_call_tracked_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(llm_call_tracked_v1, {
    call_id     :: binary(),
    venture_id  :: binary(),
    division_id :: binary() | undefined,
    agent_id    :: binary() | undefined,
    task_id     :: binary() | undefined,
    model       :: binary(),
    tokens_in   :: non_neg_integer(),
    tokens_out  :: non_neg_integer(),
    cost_usd    :: float(),
    tracked_at  :: integer()
}).

-export_type([llm_call_tracked_v1/0]).
-opaque llm_call_tracked_v1() :: #llm_call_tracked_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> llm_call_tracked_v1().
event_type() -> <<"llm_call_tracked_v1">>.

new(#{model := Model, tokens_in := TokensIn, tokens_out := TokensOut} = Params) ->
    #llm_call_tracked_v1{
        call_id     = generate_call_id(),
        venture_id  = maps:get(venture_id, Params, <<"default">>),
        division_id = maps:get(division_id, Params, undefined),
        agent_id    = maps:get(agent_id, Params, undefined),
        task_id     = maps:get(task_id, Params, undefined),
        model       = Model,
        tokens_in   = TokensIn,
        tokens_out  = TokensOut,
        cost_usd    = maps:get(cost_usd, Params, 0.0),
        tracked_at  = erlang:system_time(millisecond)
    }.

-spec to_map(llm_call_tracked_v1()) -> map().
to_map(#llm_call_tracked_v1{} = E) ->
    #{
        event_type  => <<"llm_call_tracked_v1">>,
        call_id     => E#llm_call_tracked_v1.call_id,
        venture_id  => E#llm_call_tracked_v1.venture_id,
        division_id => E#llm_call_tracked_v1.division_id,
        agent_id    => E#llm_call_tracked_v1.agent_id,
        task_id     => E#llm_call_tracked_v1.task_id,
        model       => E#llm_call_tracked_v1.model,
        tokens_in   => E#llm_call_tracked_v1.tokens_in,
        tokens_out  => E#llm_call_tracked_v1.tokens_out,
        cost_usd    => E#llm_call_tracked_v1.cost_usd,
        tracked_at  => E#llm_call_tracked_v1.tracked_at
    }.

-spec from_map(map()) -> {ok, llm_call_tracked_v1()} | {error, term()}.
from_map(Map) ->
    Model = gv(model, Map),
    case Model of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #llm_call_tracked_v1{
                call_id     = gv(call_id, Map, generate_call_id()),
                venture_id  = gv(venture_id, Map, <<"default">>),
                division_id = gv(division_id, Map, undefined),
                agent_id    = gv(agent_id, Map, undefined),
                task_id     = gv(task_id, Map, undefined),
                model       = Model,
                tokens_in   = gv(tokens_in, Map, 0),
                tokens_out  = gv(tokens_out, Map, 0),
                cost_usd    = gv(cost_usd, Map, 0.0),
                tracked_at  = gv(tracked_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Internal
generate_call_id() ->
    Ts = integer_to_binary(erlang:system_time(microsecond)),
    Unique = integer_to_binary(erlang:unique_integer([positive])),
    <<"llm-call-", Ts/binary, "-", Unique/binary>>.

gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map, Default)
    end.
