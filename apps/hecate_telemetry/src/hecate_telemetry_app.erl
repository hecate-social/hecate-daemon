%%% @doc hecate_telemetry OTP application
%%% Telemetry and cost tracking service for LLM calls.
-module(hecate_telemetry_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case hecate_telemetry_sup:start_link() of
        {ok, Pid} ->
            ok = hecate_telemetry_store:init_schema(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    ok.
