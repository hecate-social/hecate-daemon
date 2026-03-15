%%% @doc track_llm_call_v1 command
%%% Records a single LLM API call with token counts and cost.
-module(track_llm_call_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).

-record(track_llm_call_v1, {
    venture_id  :: binary(),
    division_id :: binary() | undefined,
    agent_id    :: binary() | undefined,
    task_id     :: binary() | undefined,
    model       :: binary(),
    tokens_in   :: non_neg_integer(),
    tokens_out  :: non_neg_integer(),
    cost_usd    :: float() | undefined
}).

-export_type([track_llm_call_v1/0]).
-opaque track_llm_call_v1() :: #track_llm_call_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, track_llm_call_v1()} | {error, term()}.
command_type() -> track_llm_call_v1.

new(#{model := Model, tokens_in := TokensIn, tokens_out := TokensOut} = Params) ->
    {ok, #track_llm_call_v1{
        venture_id  = maps:get(venture_id, Params, <<"default">>),
        division_id = maps:get(division_id, Params, undefined),
        agent_id    = maps:get(agent_id, Params, undefined),
        task_id     = maps:get(task_id, Params, undefined),
        model       = Model,
        tokens_in   = TokensIn,
        tokens_out  = TokensOut,
        cost_usd    = maps:get(cost_usd, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(track_llm_call_v1()) -> {ok, track_llm_call_v1()} | {error, term()}.
validate(#track_llm_call_v1{model = Model}) when
    not is_binary(Model); byte_size(Model) =:= 0 ->
    {error, invalid_model};
validate(#track_llm_call_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(track_llm_call_v1()) -> map().
to_map(#track_llm_call_v1{} = C) ->
    #{
        command_type => <<"track_llm_call">>,
        venture_id => C#track_llm_call_v1.venture_id,
        division_id => C#track_llm_call_v1.division_id,
        agent_id => C#track_llm_call_v1.agent_id,
        task_id => C#track_llm_call_v1.task_id,
        model => C#track_llm_call_v1.model,
        tokens_in => C#track_llm_call_v1.tokens_in,
        tokens_out => C#track_llm_call_v1.tokens_out,
        cost_usd => C#track_llm_call_v1.cost_usd
    }.

-spec from_map(map()) -> {ok, track_llm_call_v1()} | {error, term()}.
from_map(Map) ->
    Model    = gv(model, Map),
    TokensIn = gv(tokens_in, Map),
    TokensOut = gv(tokens_out, Map),
    case {Model, TokensIn, TokensOut} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined}  -> {error, missing_required_fields};
        _ ->
            {ok, #track_llm_call_v1{
                venture_id  = gv(venture_id, Map, <<"default">>),
                division_id = gv(division_id, Map, undefined),
                agent_id    = gv(agent_id, Map, undefined),
                task_id     = gv(task_id, Map, undefined),
                model       = Model,
                tokens_in   = TokensIn,
                tokens_out  = TokensOut,
                cost_usd    = gv(cost_usd, Map, undefined)
            }}
    end.

%% Internal
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map, Default)
    end.
