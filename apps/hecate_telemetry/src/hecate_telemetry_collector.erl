%%% @doc Instrumentation module for collecting LLM telemetry.
%%% Provides convenience functions for recording LLM calls and calculating costs.
-module(hecate_telemetry_collector).

-export([record_llm_call/1]).
-export([calculate_cost/3]).
-export([extract_tokens/1]).

%% Pricing per 1000 tokens (input, output)
-define(PRICING, #{
    %% OpenAI models
    <<"gpt-4">> => {0.03, 0.06},
    <<"gpt-4-turbo">> => {0.01, 0.03},
    <<"gpt-4o">> => {0.005, 0.015},
    <<"gpt-4o-mini">> => {0.00015, 0.0006},
    <<"gpt-3.5-turbo">> => {0.0015, 0.002},

    %% Anthropic models
    <<"claude-3-opus-20240229">> => {0.015, 0.075},
    <<"claude-3-sonnet-20240229">> => {0.003, 0.015},
    <<"claude-3-haiku-20240307">> => {0.00025, 0.00125},
    <<"claude-3-5-sonnet-20240620">> => {0.003, 0.015},
    <<"claude-3-5-sonnet-20241022">> => {0.003, 0.015},
    <<"claude-3-5-haiku-20241022">> => {0.001, 0.005},
    <<"claude-opus-4-20250514">> => {0.015, 0.075},
    <<"claude-sonnet-4-20250514">> => {0.003, 0.015},

    %% Google models
    <<"gemini-1.5-pro">> => {0.00125, 0.005},
    <<"gemini-1.5-flash">> => {0.000075, 0.0003},
    <<"gemini-2.0-flash">> => {0.0001, 0.0004},

    %% Default pricing for unknown models (conservative estimate)
    default => {0.01, 0.03}
}).

%%------------------------------------------------------------------------------
%% API
%%------------------------------------------------------------------------------

%% @doc Record an LLM call. Calculates cost if not provided.
%% Required keys: torch_id, model, tokens_in, tokens_out
%% Optional keys: cartwheel_id, agent_id, task_id, cost_usd
-spec record_llm_call(map()) -> ok | {error, term()}.
record_llm_call(Data) when is_map(Data) ->
    Model = maps:get(model, Data),
    TokensIn = maps:get(tokens_in, Data),
    TokensOut = maps:get(tokens_out, Data),

    %% Calculate cost if not provided
    DataWithCost = case maps:is_key(cost_usd, Data) of
        true -> Data;
        false ->
            Cost = calculate_cost(Model, TokensIn, TokensOut),
            Data#{cost_usd => Cost}
    end,

    hecate_telemetry_store:record_llm_call(DataWithCost).

%% @doc Calculate cost in USD for a given model and token counts.
-spec calculate_cost(binary(), non_neg_integer(), non_neg_integer()) -> float().
calculate_cost(Model, TokensIn, TokensOut) ->
    {InputPer1k, OutputPer1k} = get_pricing(Model),
    InputCost = (TokensIn / 1000) * InputPer1k,
    OutputCost = (TokensOut / 1000) * OutputPer1k,
    InputCost + OutputCost.

%% @doc Extract token counts from an LLM response.
%% Handles different response formats from various providers.
-spec extract_tokens(map()) -> {non_neg_integer(), non_neg_integer()}.
extract_tokens(Response) when is_map(Response) ->
    %% Try different common formats
    case maps:get(<<"usage">>, Response, undefined) of
        undefined ->
            %% Try atom keys
            case maps:get(usage, Response, undefined) of
                undefined ->
                    %% No usage info available
                    {0, 0};
                Usage ->
                    extract_from_usage(Usage)
            end;
        Usage ->
            extract_from_usage(Usage)
    end.

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

get_pricing(Model) when is_binary(Model) ->
    %% Try exact match first
    case maps:get(Model, ?PRICING, undefined) of
        undefined ->
            %% Try prefix matching for versioned models
            case find_pricing_by_prefix(Model) of
                undefined ->
                    %% Check if it's an Ollama model (local, free)
                    case is_ollama_model(Model) of
                        true -> {0.0, 0.0};
                        false -> maps:get(default, ?PRICING)
                    end;
                Pricing ->
                    Pricing
            end;
        Pricing ->
            Pricing
    end.

find_pricing_by_prefix(Model) ->
    Prefixes = [
        {<<"gpt-4o-mini">>, <<"gpt-4o-mini">>},
        {<<"gpt-4o">>, <<"gpt-4o">>},
        {<<"gpt-4-turbo">>, <<"gpt-4-turbo">>},
        {<<"gpt-4">>, <<"gpt-4">>},
        {<<"gpt-3.5-turbo">>, <<"gpt-3.5-turbo">>},
        {<<"claude-3-opus">>, <<"claude-3-opus-20240229">>},
        {<<"claude-3-sonnet">>, <<"claude-3-sonnet-20240229">>},
        {<<"claude-3-haiku">>, <<"claude-3-haiku-20240307">>},
        {<<"claude-3-5-sonnet">>, <<"claude-3-5-sonnet-20241022">>},
        {<<"claude-3-5-haiku">>, <<"claude-3-5-haiku-20241022">>},
        {<<"claude-opus-4">>, <<"claude-opus-4-20250514">>},
        {<<"claude-sonnet-4">>, <<"claude-sonnet-4-20250514">>},
        {<<"gemini-1.5-pro">>, <<"gemini-1.5-pro">>},
        {<<"gemini-1.5-flash">>, <<"gemini-1.5-flash">>},
        {<<"gemini-2.0-flash">>, <<"gemini-2.0-flash">>}
    ],
    find_matching_prefix(Model, Prefixes).

find_matching_prefix(_Model, []) ->
    undefined;
find_matching_prefix(Model, [{Prefix, Key} | Rest]) ->
    case binary:match(Model, Prefix) of
        {0, _} -> maps:get(Key, ?PRICING, undefined);
        _ -> find_matching_prefix(Model, Rest)
    end.

is_ollama_model(Model) ->
    %% Ollama models typically don't have version suffixes like OpenAI/Anthropic
    %% Common Ollama patterns: llama3, mistral, codellama, etc.
    OllamaPatterns = [
        <<"llama">>,
        <<"mistral">>,
        <<"codellama">>,
        <<"mixtral">>,
        <<"phi">>,
        <<"gemma">>,
        <<"qwen">>,
        <<"deepseek">>,
        <<"starcoder">>,
        <<"wizard">>,
        <<"vicuna">>,
        <<"orca">>,
        <<"neural">>,
        <<"dolphin">>,
        <<"nous">>
    ],
    lists:any(fun(Pattern) ->
        case binary:match(string:lowercase(Model), Pattern) of
            nomatch -> false;
            _ -> true
        end
    end, OllamaPatterns).

extract_from_usage(Usage) when is_map(Usage) ->
    %% Handle both binary and atom keys
    PromptTokens = get_usage_field(Usage, [<<"prompt_tokens">>, prompt_tokens, <<"input_tokens">>, input_tokens]),
    CompletionTokens = get_usage_field(Usage, [<<"completion_tokens">>, completion_tokens, <<"output_tokens">>, output_tokens]),
    {PromptTokens, CompletionTokens}.

get_usage_field(Usage, []) ->
    case maps:get(<<"total_tokens">>, Usage, maps:get(total_tokens, Usage, 0)) of
        Total when is_integer(Total), Total > 0 ->
            %% If we only have total, assume 50/50 split (rough estimate)
            Total div 2;
        _ ->
            0
    end;
get_usage_field(Usage, [Key | Rest]) ->
    case maps:get(Key, Usage, undefined) of
        undefined -> get_usage_field(Usage, Rest);
        Value when is_integer(Value) -> Value;
        _ -> get_usage_field(Usage, Rest)
    end.
