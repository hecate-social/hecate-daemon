%%% @doc Chat to LLM
%%% Dispatches chat completion to the appropriate provider via manage_providers.
%%% Instruments all calls with hecate_telemetry for cost tracking.
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

%% Record telemetry for LLM calls
record_telemetry(Model, {ok, Response}, Opts) ->
    %% Extract token counts from response
    TokensIn = maps:get(prompt_eval_count, Response,
                  maps:get(<<"prompt_eval_count">>, Response, 0)),
    TokensOut = maps:get(eval_count, Response,
                   maps:get(<<"eval_count">>, Response, 0)),

    %% Only record if we have token data
    case TokensIn + TokensOut of
        0 -> ok;
        _ ->
            TelemetryData = #{
                model => Model,
                tokens_in => TokensIn,
                tokens_out => TokensOut,
                torch_id => maps:get(torch_id, Opts, <<"default">>),
                cartwheel_id => maps:get(cartwheel_id, Opts, undefined),
                agent_id => maps:get(agent_id, Opts, undefined),
                task_id => maps:get(task_id, Opts, undefined)
            },
            %% Call telemetry collector if available
            try
                hecate_telemetry_collector:record_llm_call(TelemetryData)
            catch
                error:undef -> ok;  %% Module not loaded yet
                _:_ -> ok
            end
    end;
record_telemetry(_Model, _Error, _Opts) ->
    ok.

%% @doc Start a streaming chat completion.
%% Returns {ok, Ref} where Ref is used to identify chunks.
%% The caller receives messages:
%%   {llm_chunk, Ref, ChunkMap} - for each chunk
%%   {llm_done, Ref} - when complete
%%   {llm_error, Ref, Reason} - on error
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
