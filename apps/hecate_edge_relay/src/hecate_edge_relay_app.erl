%%%-------------------------------------------------------------------
%%% @doc T3 Edge Relay application — optional LAN relay role.
%%%
%%% When enabled, starts a QUIC listener on a LAN address so nearby
%%% nodes can connect locally. Routes pub/sub via pg groups and
%%% forwards WAN traffic through hecate_mesh.
%%%
%%% Controlled by HECATE_EDGE_RELAY env var (default: disabled).
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_edge_relay_app).

-behaviour(application).

-include_lib("kernel/include/logger.hrl").

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case is_enabled() of
        true ->
            Port = edge_relay_port(),
            ?LOG_INFO("[edge_relay] Starting T3 edge relay on port ~b", [Port]),
            hecate_edge_relay_sup:start_link(#{port => Port});
        false ->
            ?LOG_INFO("[edge_relay] Disabled (set HECATE_EDGE_RELAY=true to enable)"),
            %% Return a minimal supervisor that does nothing
            hecate_edge_relay_sup:start_link(disabled)
    end.

stop(_State) ->
    ok.

%%====================================================================
%% Internal
%%====================================================================

is_enabled() ->
    case os:getenv("HECATE_EDGE_RELAY") of
        "true" -> true;
        "1" -> true;
        _ -> application:get_env(hecate, edge_relay, false)
    end.

edge_relay_port() ->
    case os:getenv("HECATE_EDGE_RELAY_PORT") of
        false -> application:get_env(hecate, edge_relay_port, 4433);
        PortStr ->
            try list_to_integer(string:trim(PortStr))
            catch error:badarg -> 4433
            end
    end.
