%%% @doc query_procurements application behaviour
-module(query_procurements_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    query_procurements_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
