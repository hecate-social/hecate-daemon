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
            ensure_cert_dir(),
            ?LOG_INFO("[edge_relay] Starting T3 edge relay on port ~b", [Port]),
            case hecate_edge_relay_sup:start_link(#{port => Port}) of
                {ok, Pid} ->
                    {ok, Pid};
                {error, Reason} ->
                    ?LOG_ERROR("[edge_relay] Failed to start: ~p — running without edge relay", [Reason]),
                    hecate_edge_relay_sup:start_link(disabled)
            end;
        false ->
            ?LOG_INFO("[edge_relay] Disabled (set HECATE_EDGE_RELAY=true to enable)"),
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

%% Ensure the TLS cert directory exists (macula_tls uses /var/lib/macula/)
ensure_cert_dir() ->
    CertDir = "/var/lib/macula",
    case filelib:is_dir(CertDir) of
        true -> ok;
        false ->
            ?LOG_INFO("[edge_relay] Creating cert directory: ~s", [CertDir]),
            filelib:ensure_dir(CertDir ++ "/"),
            file:make_dir(CertDir)
    end.
