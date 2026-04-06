%%%-------------------------------------------------------------------
%%% @doc Per-connection handler for T3 edge relay.
%%%
%%% Handles a single LAN client's QUIC stream. Routes messages:
%%% - PUBLISH: deliver to local pg group + forward to WAN via hecate_mesh
%%% - SUBSCRIBE: join local pg group + subscribe on WAN via hecate_mesh
%%% - CALL: check local gproc, fallback to WAN via hecate_mesh
%%% - REPLY: route back to caller
%%%
%%% Adapted from macula_relay_handler — no peering logic, WAN uplink
%%% via hecate_mesh instead of peer relay clients.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_edge_relay_handler).

-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    conn :: reference(),
    stream :: reference(),
    node_id :: binary(),
    node_name :: binary(),
    identified :: boolean(),
    pending_msgs :: [term()],
    recv_buffer :: binary(),
    pending_calls :: #{binary() => pid()},
    wan_subs :: #{binary() => reference()}   %% topic => hecate_mesh sub ref
}).

start_link(Conn, Stream) ->
    gen_server:start_link(?MODULE, {Conn, Stream}, []).

init({Conn, Stream}) ->
    {ok, #state{
        conn = Conn,
        stream = Stream,
        node_id = <<>>,
        node_name = <<>>,
        identified = false,
        pending_msgs = [],
        recv_buffer = <<>>,
        pending_calls = #{},
        wan_subs = #{}
    }}.

%%====================================================================
%% Ownership transfer — stream goes active
%%====================================================================

handle_info(ownership_transferred, #state{stream = Stream} = State) ->
    quicer:setopt(Stream, active, true),
    ?LOG_INFO("[edge_handler] Ownership received, stream active"),
    {noreply, State};

%%====================================================================
%% QUIC data
%%====================================================================

handle_info({quic, Data, Stream, _Flags}, #state{stream = Stream} = State)
  when is_binary(Data) ->
    Buffer = <<(State#state.recv_buffer)/binary, Data/binary>>,
    {NewBuffer, State2} = process_buffer(Buffer, State),
    {noreply, State2#state{recv_buffer = NewBuffer}};

%%====================================================================
%% Local pub/sub delivery (from other edge relay handlers via pg)
%%====================================================================

handle_info({relay_publish, Topic, Payload}, State) ->
    send_to_client(publish, #{
        <<"topic">> => Topic,
        <<"payload">> => Payload,
        <<"qos">> => 0,
        <<"retain">> => false,
        <<"message_id">> => crypto:strong_rand_bytes(16)
    }, State),
    {noreply, State};

%%====================================================================
%% RPC forwarding from other local handlers
%%====================================================================

handle_info({relay_call, CallerPid, CallId, Procedure, Args}, State) ->
    PendingCalls = maps:put(CallId, CallerPid, State#state.pending_calls),
    send_to_client(call, #{
        <<"call_id">> => CallId,
        <<"procedure">> => Procedure,
        <<"args">> => Args
    }, State),
    {noreply, State#state{pending_calls = PendingCalls}};

handle_info({relay_reply, CallId, Result}, State) ->
    send_to_client(reply, #{
        <<"call_id">> => CallId,
        <<"result">> => Result
    }, State),
    {noreply, State};

%%====================================================================
%% WAN message arrived (forwarded from hecate_mesh subscription)
%%====================================================================

handle_info({wan_publish, Topic, Payload}, State) ->
    %% Deliver to all local LAN subscribers (including this client)
    Members = try pg:get_members(pg, {edge_local, Topic}) catch _:_ -> [] end,
    lists:foreach(fun(Pid) ->
        Pid ! {relay_publish, Topic, Payload}
    end, Members),
    {noreply, State};

%%====================================================================
%% QUIC lifecycle
%%====================================================================

handle_info({quic, peer_send_shutdown, _Stream, _}, State) ->
    {stop, normal, State};
handle_info({quic, peer_send_aborted, _Stream, _}, State) ->
    {stop, normal, State};
handle_info({quic, shutdown, _Ref, _Reason}, State) ->
    {stop, normal, State};
handle_info({quic, closed, _Ref, _Reason}, State) ->
    {stop, normal, State};
handle_info({quic, transport_shutdown, _Ref, _Reason}, State) ->
    {stop, normal, State};
handle_info({quic, streams_available, _Conn, _Info}, State) ->
    {noreply, State};
handle_info({quic, peer_needs_streams, _Conn, _Info}, State) ->
    {noreply, State};

handle_info(Info, State) ->
    ?LOG_DEBUG("[edge_handler] Unhandled: ~p", [Info]),
    {noreply, State}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

terminate(Reason, #state{node_name = NodeName, wan_subs = WanSubs}) ->
    %% Unsubscribe WAN subscriptions we created for this client
    maps:foreach(fun(_Topic, SubRef) ->
        catch hecate_mesh:unsubscribe(SubRef)
    end, WanSubs),
    ?LOG_INFO("[edge_handler] Client ~s disconnected: ~p", [NodeName, Reason]),
    ok.

%%====================================================================
%% Protocol message processing
%%====================================================================

process_buffer(Buffer, State) when byte_size(Buffer) < 8 ->
    {Buffer, State};
process_buffer(<<_Version:8, _TypeId:8, _Flags:8, _Reserved:8,
                 PayloadLen:32/big-unsigned, Rest/binary>> = Buffer, State) ->
    case byte_size(Rest) >= PayloadLen of
        true ->
            MsgBytes = binary:part(Buffer, 0, 8 + PayloadLen),
            Remaining = binary:part(Buffer, 8 + PayloadLen, byte_size(Buffer) - 8 - PayloadLen),
            State2 = handle_message(macula_protocol_decoder:decode(MsgBytes), State),
            process_buffer(Remaining, State2);
        false ->
            {Buffer, State}
    end.

%%--------------------------------------------------------------------
%% CONNECT — identify the LAN client
%%--------------------------------------------------------------------

handle_message({ok, {connect, Msg}}, State) ->
    NodeId = maps:get(<<"node_id">>, Msg, <<>>),
    NodeName = maps:get(<<"node_name">>, Msg, binary:encode_hex(NodeId)),
    ?LOG_INFO("[edge_handler] LAN client connected: ~s", [NodeName]),
    pg:join(pg, edge_connected_nodes, self()),
    send_to_client(pong, #{
        <<"timestamp">> => erlang:system_time(millisecond),
        <<"server_time">> => erlang:system_time(millisecond),
        <<"edge_relay">> => true
    }, State),
    State2 = State#state{node_id = NodeId, node_name = NodeName, identified = true},
    replay_pending(State2);

%%--------------------------------------------------------------------
%% SUBSCRIBE — join local pg + bridge to WAN
%%--------------------------------------------------------------------

handle_message({ok, {subscribe, Msg}}, State) ->
    Topics = maps:get(<<"topics">>, Msg, []),
    WanSubs = lists:foldl(fun(Topic, Acc) ->
        %% Join local edge pg groups
        pg:join(pg, {edge_topic, Topic}, self()),
        pg:join(pg, {edge_local, Topic}, self()),
        %% Bridge to WAN — check cache to avoid re-subscribing
        case maps:is_key(Topic, Acc) of
            true -> Acc;
            false ->
                case hecate_edge_relay_cache:should_bridge(Topic) of
                    skip ->
                        Acc;
                    bridge ->
                        Self = self(),
                        Callback = fun(#{payload := Payload}) ->
                            Self ! {wan_publish, Topic, Payload}
                        end,
                        case hecate_mesh:subscribe(Topic, Callback) of
                            {ok, SubRef} ->
                                hecate_edge_relay_cache:mark_bridged(Topic),
                                ?LOG_INFO("[edge_handler] Bridged ~s to WAN", [Topic]),
                                Acc#{Topic => SubRef};
                            _ -> Acc
                        end
                end
        end
    end, State#state.wan_subs, Topics),
    State#state{wan_subs = WanSubs};

%%--------------------------------------------------------------------
%% PUBLISH — deliver locally + forward to WAN
%%--------------------------------------------------------------------

handle_message({ok, {publish, Msg}}, State) ->
    Topic = maps:get(<<"topic">>, Msg, <<>>),
    Payload = maps:get(<<"payload">>, Msg, <<>>),
    %% Deliver to all local edge subscribers (except self)
    Members = try pg:get_members(pg, {edge_topic, Topic}) catch _:_ -> [] end,
    lists:foreach(fun(Pid) ->
        case Pid =/= self() of
            true -> Pid ! {relay_publish, Topic, Payload};
            false -> ok
        end
    end, Members),
    %% Forward to WAN via hecate_mesh
    hecate_mesh:publish(Topic, Payload),
    State;

%%--------------------------------------------------------------------
%% REGISTER_PROCEDURE — register locally + advertise on WAN
%%--------------------------------------------------------------------

handle_message({ok, {register_procedure, Msg}}, State) ->
    Procedure = maps:get(<<"procedure">>, Msg, <<>>),
    try
        gproc:reg({p, l, {edge_rpc, Procedure}}),
        ?LOG_INFO("[edge_handler] Registered LAN procedure: ~s", [Procedure])
    catch
        _:_ -> ok
    end,
    %% Also advertise on WAN so remote nodes can call this procedure
    Self = self(),
    Handler = fun(Args) ->
        %% Forward WAN RPC call to the LAN client
        CallId = base64:encode(crypto:strong_rand_bytes(12)),
        Self ! {relay_call, self(), CallId, Procedure, Args},
        %% Wait for reply from LAN client
        receive
            {relay_reply, CallId, Result} -> {ok, Result}
        after 5000 ->
            {error, <<"edge_timeout">>}
        end
    end,
    hecate_mesh:advertise(Procedure, Handler),
    State;

%%--------------------------------------------------------------------
%% CALL — check local edge, fallback to WAN
%%--------------------------------------------------------------------

handle_message({ok, {call, Msg}}, State) ->
    Procedure = maps:get(<<"procedure">>, Msg, <<>>),
    CallId = maps:get(<<"call_id">>, Msg, <<>>),
    Args = maps:get(<<"args">>, Msg, #{}),
    case gproc:lookup_pids({p, l, {edge_rpc, Procedure}}) of
        [] ->
            %% Not local — forward to WAN
            HandlerPid = self(),
            spawn(fun() ->
                case hecate_mesh:call(Procedure, Args, 5000) of
                    {ok, Result} ->
                        HandlerPid ! {relay_reply, CallId, Result};
                    {error, Reason} ->
                        HandlerPid ! {relay_reply, CallId,
                            #{<<"error">> => #{<<"code">> => <<"wan_error">>,
                                               <<"message">> => iolist_to_binary(
                                                   io_lib:format("~p", [Reason]))}}}
                end
            end);
        [ProviderPid | _] when ProviderPid =/= self() ->
            ProviderPid ! {relay_call, self(), CallId, Procedure, Args};
        _ ->
            %% Provider is self — shouldn't happen, but handle gracefully
            send_to_client(reply, #{
                <<"call_id">> => CallId,
                <<"error">> => #{<<"code">> => <<"self_call">>}
            }, State)
    end,
    State;

%%--------------------------------------------------------------------
%% REPLY — route back to caller
%%--------------------------------------------------------------------

handle_message({ok, {reply, Msg}}, State) ->
    CallId = maps:get(<<"call_id">>, Msg, <<>>),
    Result = maps:get(<<"result">>, Msg, maps:get(<<"error">>, Msg, #{})),
    case maps:get(CallId, State#state.pending_calls, undefined) of
        undefined -> ok;
        CallerPid -> CallerPid ! {relay_reply, CallId, Result}
    end,
    State#state{pending_calls = maps:remove(CallId, State#state.pending_calls)};

%%--------------------------------------------------------------------
%% Buffer messages before CONNECT
%%--------------------------------------------------------------------

handle_message({ok, {Type, _}} = Msg, #state{identified = false, pending_msgs = Pending} = State)
  when Type =/= connect ->
    State#state{pending_msgs = [Msg | Pending]};

handle_message({ok, {pong, _}}, State) ->
    State;

handle_message({ok, {Type, _}}, State) ->
    ?LOG_DEBUG("[edge_handler] Ignoring message type: ~p", [Type]),
    State;

handle_message({error, Reason}, State) ->
    ?LOG_WARNING("[edge_handler] Decode error: ~p", [Reason]),
    State.

%%====================================================================
%% Internal
%%====================================================================

send_to_client(Type, Msg, #state{stream = Stream}) ->
    Binary = macula_protocol_encoder:encode(Type, Msg),
    case macula_quic:async_send(Stream, Binary) of
        ok -> ok;
        {error, Reason} ->
            ?LOG_WARNING("[edge_handler] Send ~p failed: ~p", [Type, Reason])
    end.

replay_pending(#state{pending_msgs = Pending} = State) ->
    State2 = State#state{pending_msgs = []},
    lists:foldl(fun(Msg, S) -> handle_message(Msg, S) end, State2, lists:reverse(Pending)).
