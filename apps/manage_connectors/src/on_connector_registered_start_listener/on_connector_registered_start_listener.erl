%%% @doc Process Manager: On connector lifecycle events, manage Cowboy listeners.
%%%
%%% Subscribes to connector events from manage_connectors_store:
%%% - connector_registered_v1 → create socket dir, clean stale socket, start listener
%%% - connector_revoked_v1 → stop listener, delete socket
%%% - connector_suspended_v1 → stop listener (keep socket for status indication)
%%% - connector_activated_v1 → start listener on existing socket path
-module(on_connector_registered_start_listener).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [subscribe_to_connector_events/0]}).

-record(state, {
    subscription_ref :: reference() | undefined,
    %% Track active listeners: connector_id => #{socket_path, listener_ref}
    active_listeners :: map()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    self() ! subscribe,
    self() ! rebuild_from_state,
    {ok, #state{
        subscription_ref = undefined,
        active_listeners = #{}
    }}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    SubRef = subscribe_to_connector_events(),
    {noreply, State#state{subscription_ref = SubRef}};

handle_info(rebuild_from_state, State) ->
    %% On startup, rebuild listeners from event-sourced state.
    %% The stale sockets were already cleaned by manage_connectors_sup.
    %% For now, the default TUI connector is auto-registered by hecate_api_app
    %% which will dispatch a register command, triggering this PM via events.
    {noreply, State};

handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, State) ->
    NewState = handle_event(EventType, EventData, State),
    {noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{active_listeners = Listeners}) ->
    %% Stop all active listeners on shutdown
    maps:foreach(fun(ConnId, _Info) ->
        stop_listener(ConnId)
    end, Listeners),
    ok.

%% Internal

subscribe_to_connector_events() ->
    case reckon_evoq_adapter:subscribe(
        manage_connectors_store,
        stream,
        <<"connectors">>,
        <<"on_connector_registered_start_listener">>,
        #{start_from => 0, subscriber_pid => self()}
    ) of
        {ok, SubRef} -> SubRef;
        {error, _} -> undefined
    end.

handle_event(<<"connector_registered_v1">>, EventData, State) ->
    ConnId = maps:get(connector_id, EventData,
                 maps:get(<<"connector_id">>, EventData, undefined)),
    SocketPath = maps:get(socket_path, EventData,
                     maps:get(<<"socket_path">>, EventData, undefined)),
    AllowedRoutes = maps:get(allowed_routes, EventData,
                        maps:get(<<"allowed_routes">>, EventData, all)),

    case start_connector_listener(ConnId, SocketPath, AllowedRoutes) of
        ok ->
            ListenerInfo = #{socket_path => SocketPath, allowed_routes => AllowedRoutes},
            Listeners = maps:put(ConnId, ListenerInfo, State#state.active_listeners),
            State#state{active_listeners = Listeners};
        {error, Reason} ->
            logger:error("[PM] Failed to start listener for ~s: ~p", [ConnId, Reason]),
            State
    end;

handle_event(<<"connector_revoked_v1">>, EventData, State) ->
    ConnId = maps:get(connector_id, EventData,
                 maps:get(<<"connector_id">>, EventData, undefined)),
    stop_listener(ConnId),
    %% Delete socket file
    case maps:get(ConnId, State#state.active_listeners, undefined) of
        #{socket_path := Path} ->
            file:delete(Path);
        _ ->
            ok
    end,
    Listeners = maps:remove(ConnId, State#state.active_listeners),
    State#state{active_listeners = Listeners};

handle_event(<<"connector_suspended_v1">>, EventData, State) ->
    ConnId = maps:get(connector_id, EventData,
                 maps:get(<<"connector_id">>, EventData, undefined)),
    stop_listener(ConnId),
    Listeners = maps:remove(ConnId, State#state.active_listeners),
    State#state{active_listeners = Listeners};

handle_event(<<"connector_activated_v1">>, EventData, State) ->
    ConnId = maps:get(connector_id, EventData,
                 maps:get(<<"connector_id">>, EventData, undefined)),
    %% Re-start the listener. We need to look up the socket path from
    %% stored listener info or from the aggregate state.
    case maps:get(ConnId, State#state.active_listeners, undefined) of
        undefined ->
            %% Listener info not cached; need the socket path.
            %% The aggregate state has it, but we don't query aggregates from PMs.
            %% The activated event should carry enough context, or we rebuild.
            logger:warning("[PM] Cannot reactivate ~s: no cached listener info", [ConnId]),
            State;
        #{socket_path := SocketPath, allowed_routes := AllowedRoutes} ->
            case start_connector_listener(ConnId, SocketPath, AllowedRoutes) of
                ok -> State;
                {error, Reason} ->
                    logger:error("[PM] Failed to reactivate ~s: ~p", [ConnId, Reason]),
                    State
            end
    end;

handle_event(_, _, State) ->
    State.

%% @private Start a Cowboy listener on a Unix domain socket.
start_connector_listener(ConnId, SocketPath, AllowedRoutes) ->
    %% Ensure the connectors directory exists
    Dir = filename:dirname(SocketPath),
    filelib:ensure_dir(filename:join(Dir, "dummy")),

    %% Remove stale socket file if it exists
    file:delete(SocketPath),

    %% Resolve socket path to a list for gen_tcp
    SocketPathStr = resolve_socket_path(SocketPath),

    %% Compile dispatch with scope middleware
    Dispatch = hecate_api_routes:compile(),
    ListenerRef = {hecate_connector, ConnId},

    Env = #{
        dispatch => Dispatch,
        allowed_routes => AllowedRoutes
    },

    %% Build middleware chain: scope check then router then handler
    Middlewares = case AllowedRoutes of
        all ->
            [cowboy_router, cowboy_handler];
        _ ->
            [connector_scope_middleware, cowboy_router, cowboy_handler]
    end,

    TransportOpts = #{
        socket_opts => [
            {ifaddr, {local, SocketPathStr}},
            {port, 0}
        ],
        num_acceptors => 2
    },

    ProtocolOpts = #{
        env => Env,
        middlewares => Middlewares
    },

    case cowboy:start_clear(ListenerRef, TransportOpts, ProtocolOpts) of
        {ok, _Pid} ->
            %% Set socket permissions: owner read/write only
            file:change_mode(SocketPathStr, 8#600),
            logger:info("[PM] Started connector listener ~s on ~s", [ConnId, SocketPath]),
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

%% @private Stop a connector's Cowboy listener.
stop_listener(ConnId) ->
    ListenerRef = {hecate_connector, ConnId},
    case cowboy:stop_listener(ListenerRef) of
        ok ->
            logger:info("[PM] Stopped connector listener ~s", [ConnId]);
        {error, not_found} ->
            ok
    end.

%% @private Resolve socket path to string for gen_tcp.
resolve_socket_path(Path) when is_binary(Path) ->
    binary_to_list(Path);
resolve_socket_path(Path) when is_list(Path) ->
    Path.
