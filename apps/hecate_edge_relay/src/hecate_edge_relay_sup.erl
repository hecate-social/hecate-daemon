%%%-------------------------------------------------------------------
%%% @doc Edge relay supervisor.
%%%
%%% When enabled: supervises the QUIC listener.
%%% When disabled: empty supervisor (application still starts cleanly).
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_edge_relay_sup).

-behaviour(supervisor).

-export([start_link/1]).
-export([init/1]).

start_link(disabled) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, disabled);
start_link(Opts) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, Opts).

init(disabled) ->
    {ok, {#{strategy => one_for_one}, []}};
init(#{port := Port}) ->
    Children = [
        #{
            id => hecate_edge_relay_listener,
            start => {hecate_edge_relay_listener, start_link, [#{port => Port}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hecate_edge_relay_listener]
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, Children}}.
