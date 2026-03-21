%%% @doc SSE endpoint: GET /api/mesh/events
%%%
%%% Real-time Server-Sent Events for mesh peer lifecycle changes.
%%% Joins the macula_mesh_lifecycle pg group to receive:
%%%   - mesh_peer_connected   — a new peer joined the mesh
%%%   - mesh_peer_disconnected — a peer left the mesh
%%%   - mesh_peers_initial    — initial peer list from PONG
%%%
%%% On connect: sends current peer list as initial state.
%%% @end
-module(mesh_events_stream_api).

-export([init/2, routes/0]).

-define(HEARTBEAT_MS, 30000).

routes() -> [{"/api/mesh/events", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> start_stream(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

start_stream(Req0, _State) ->
    ensure_pg_scope(),
    pg:join(pg, macula_mesh_lifecycle, self()),

    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>
    }, Req0),

    %% Send initial state
    send_initial_state(Req1),

    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
    stream_loop(Req1).

stream_loop(Req) ->
    receive
        {macula_mesh_event, EventType, PeerInfo} ->
            send_event(Req, EventType, PeerInfo);
        heartbeat ->
            send_heartbeat(Req);
        _ ->
            stream_loop(Req)
    end.

send_event(Req, EventType, PeerInfo) ->
    TypeBin = atom_to_binary(EventType),
    DataBin = iolist_to_binary(json:encode(PeerInfo)),
    Payload = <<"event: ", TypeBin/binary, "\ndata: ", DataBin/binary, "\n\n">>,
    case catch cowboy_req:stream_body(Payload, nofin, Req) of
        ok -> stream_loop(Req);
        _ -> {ok, Req, []}
    end.

send_heartbeat(Req) ->
    case catch cowboy_req:stream_body(<<": heartbeat\n\n">>, nofin, Req) of
        ok ->
            erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
            stream_loop(Req);
        _ ->
            {ok, Req, []}
    end.

send_initial_state(Req) ->
    case hecate_mesh:get_peers() of
        {ok, Peers} ->
            Status = case hecate_mesh:get_status() of
                {ok, S} -> S;
                _ -> #{}
            end,
            InitData = #{
                peers => Peers,
                self => maps:with([node_id, identity, realm], Status),
                connected => maps:get(connected, Status, false)
            },
            DataBin = iolist_to_binary(json:encode(InitData)),
            cowboy_req:stream_body(
                <<"event: mesh_initial\ndata: ", DataBin/binary, "\n\n">>,
                nofin, Req);
        _ ->
            ok
    end.

ensure_pg_scope() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
