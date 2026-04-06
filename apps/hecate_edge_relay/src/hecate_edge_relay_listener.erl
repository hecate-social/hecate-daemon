%%%-------------------------------------------------------------------
%%% @doc QUIC listener for the T3 edge relay.
%%%
%%% Accepts QUIC connections on a LAN address. For each connection,
%%% spawns a hecate_edge_relay_handler that routes messages locally
%%% via pg groups and forwards WAN traffic through hecate_mesh.
%%%
%%% Adapted from macula_relay.erl — simplified for edge use:
%%% no peering, no identity management, no admin API.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_edge_relay_listener).

-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/1]).
-export([init/1, handle_info/2, terminate/2, handle_call/3, handle_cast/2]).

-record(state, {
    listener :: reference() | undefined,
    port :: non_neg_integer(),
    handlers :: [pid()]
}).

start_link(Opts) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Opts, []).

init(#{port := Port}) ->
    process_flag(trap_exit, true),
    %% macula_quic:listen/2 expects {cert, Path} and {key, Path} —
    %% it internally converts to {certfile, ...} for quicer.
    %% Do NOT pass macula_tls:quic_server_opts() which uses {certfile, ...} directly.
    {CertPath, KeyPath} = macula_tls:get_cert_paths(),
    macula_tls:ensure_cert_exists(CertPath, KeyPath),
    ListenOpts = [
        {cert, CertPath},
        {key, KeyPath},
        {alpn, ["macula"]},
        {idle_timeout_ms, 120000},
        {keep_alive_interval_ms, 30000},
        {peer_unidi_stream_count, 3},
        {peer_bidi_stream_count, 100}
    ],
    case macula_quic:listen(Port, ListenOpts) of
        {ok, Listener} ->
            ?LOG_INFO("[edge_relay] Listening on port ~b", [Port]),
            register_accept(Listener),
            {ok, #state{listener = Listener, port = Port, handlers = []}};
        {error, Reason} ->
            ?LOG_ERROR("[edge_relay] Listen failed on port ~b: ~p — will retry in 10s", [Port, Reason]),
            erlang:send_after(10000, self(), retry_listen),
            {ok, #state{listener = undefined, port = Port, handlers = []}}
    end.

%%====================================================================
%% Connection acceptance
%%====================================================================

handle_info(retry_listen, #state{port = Port, listener = undefined} = State) ->
    {CertPath, KeyPath} = macula_tls:get_cert_paths(),
    macula_tls:ensure_cert_exists(CertPath, KeyPath),
    ListenOpts = [
        {cert, CertPath},
        {key, KeyPath},
        {alpn, ["macula"]},
        {idle_timeout_ms, 120000},
        {keep_alive_interval_ms, 30000},
        {peer_unidi_stream_count, 3},
        {peer_bidi_stream_count, 100}
    ],
    case macula_quic:listen(Port, ListenOpts) of
        {ok, Listener} ->
            ?LOG_INFO("[edge_relay] Listening on port ~b (retry succeeded)", [Port]),
            register_accept(Listener),
            {noreply, State#state{listener = Listener}};
        {error, Reason} ->
            ?LOG_WARNING("[edge_relay] Retry listen failed: ~p — retrying in 30s", [Reason]),
            erlang:send_after(30000, self(), retry_listen),
            {noreply, State}
    end;
handle_info(retry_listen, State) ->
    {noreply, State};

handle_info({quic, new_conn, Conn, ConnInfo}, #state{listener = Listener} = State) ->
    ?LOG_INFO("[edge_relay] New LAN connection: ~p", [ConnInfo]),
    complete_handshake(Conn),
    register_accept(Listener),
    {noreply, State};

handle_info({quic, new_stream, Stream, StreamProps}, State) ->
    catch quicer:setopt(Stream, active, false),
    Conn = case StreamProps of
        #{conn := C} -> C;
        _ -> get(pending_conn)
    end,
    case Conn of
        undefined ->
            ?LOG_WARNING("[edge_relay] Stream with no connection context"),
            {noreply, State};
        _ ->
            {ok, Pid} = hecate_edge_relay_handler:start_link(Conn, Stream),
            case quicer:controlling_process(Stream, Pid) of
                ok ->
                    _ = quicer:controlling_process(Conn, Pid),
                    Pid ! ownership_transferred,
                    ?LOG_INFO("[edge_relay] Handler ~p started for LAN client", [Pid]),
                    {noreply, State#state{handlers = [Pid | State#state.handlers]}};
                {error, Reason} ->
                    ?LOG_WARNING("[edge_relay] Stream ownership transfer failed: ~p", [Reason]),
                    {noreply, State}
            end
    end;

%%====================================================================
%% Handler lifecycle
%%====================================================================

handle_info({'EXIT', Pid, Reason}, State) ->
    case lists:member(Pid, State#state.handlers) of
        true ->
            ?LOG_INFO("[edge_relay] Handler ~p exited: ~p", [Pid, Reason]),
            {noreply, State#state{handlers = lists:delete(Pid, State#state.handlers)}};
        false ->
            {noreply, State}
    end;

handle_info({quic, streams_available, _Conn, _Info}, State) ->
    {noreply, State};
handle_info({quic, peer_needs_streams, _Conn, _Info}, State) ->
    {noreply, State};

handle_info(Info, State) ->
    ?LOG_DEBUG("[edge_relay] Unhandled: ~p", [Info]),
    {noreply, State}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #state{listener = Listener}) ->
    catch macula_quic:close(Listener),
    ok.

%%====================================================================
%% Internal
%%====================================================================

register_accept(Listener) ->
    case quicer:async_accept(Listener, #{}) of
        {ok, _} -> ok;
        {error, Reason} ->
            ?LOG_WARNING("[edge_relay] async_accept failed: ~p", [Reason]),
            ok
    end.

complete_handshake(Conn) ->
    case quicer:handshake(Conn) of
        ok -> accept_streams(Conn);
        {ok, _} -> accept_streams(Conn);
        {error, Reason} ->
            ?LOG_ERROR("[edge_relay] Handshake failed: ~p", [Reason]),
            catch quicer:close_connection(Conn)
    end.

accept_streams(Conn) ->
    put(pending_conn, Conn),
    case quicer:async_accept_stream(Conn, #{}) of
        {ok, _} -> ok;
        {error, Reason} ->
            ?LOG_WARNING("[edge_relay] async_accept_stream failed: ~p", [Reason]),
            ok
    end.
