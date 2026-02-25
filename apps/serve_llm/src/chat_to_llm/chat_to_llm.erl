%%% @doc Chat to LLM
%%% Dispatches chat completion to the appropriate provider via manage_providers.
%%% Instruments all calls with llm_pricing for cost tracking.
-module(chat_to_llm).

-export([chat/2, chat/3, chat_stream/3]).

%% Suppress dialyzer supertype warning (map() is intentionally general for API)
-dialyzer({nowarn_function, [chat/2, chat/3, record_telemetry/3]}).

-spec chat(binary(), list()) -> {ok, map()} | {error, term()}.
chat(Model, Messages) ->
    chat(Model, Messages, #{}).

-spec chat(binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Model, Messages, Opts) ->
    case manage_providers:provider_for_model(Model) of
        {error, not_found} ->
            {error, {unknown_model, Model}};
        {Mod, Config} ->
            Result = Mod:chat(Config, Model, Messages, Opts),
            record_telemetry(Model, Result, Opts),
            Result
    end.

record_telemetry(Model, {ok, Response}, Opts) ->
    TokensIn = maps:get(prompt_eval_count, Response,
                  maps:get(<<"prompt_eval_count">>, Response, 0)),
    TokensOut = maps:get(eval_count, Response,
                   maps:get(<<"eval_count">>, Response, 0)),
    case TokensIn + TokensOut of
        0 -> ok;
        _ ->
            TelemetryData = #{
                model => Model,
                tokens_in => TokensIn,
                tokens_out => TokensOut,
                venture_id => maps:get(venture_id, Opts, <<"default">>),
                division_id => maps:get(division_id, Opts, undefined),
                agent_id => maps:get(agent_id, Opts, undefined),
                task_id => maps:get(task_id, Opts, undefined)
            },
            try
                llm_pricing:record_llm_call(TelemetryData)
            catch
                error:undef -> ok;
                _:_ -> ok
            end
    end;
record_telemetry(_Model, _Error, _Opts) ->
    ok.

%% @doc Start a streaming chat completion.
-spec chat_stream(binary(), list(), map()) -> {ok, reference()} | {error, term()}.
chat_stream(Model, Messages, Opts) ->
    case manage_providers:provider_for_model(Model) of
        {error, not_found} ->
            {error, {unknown_model, Model}};
        {Mod, Config} ->
            Ref = make_ref(),
            Caller = self(),
            spawn_link(fun() -> Mod:chat_stream(Config, Model, Messages, Opts, Caller, Ref) end),
            {ok, Ref}
    end.
