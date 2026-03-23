%%% @doc Handler for host_game command
-module(maybe_host_game).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    GameId = maps:get(game_id, Payload, <<>>),
    HostNodeId = maps:get(host_node_id, Payload, <<>>),
    MaxPlayers = maps:get(max_players, Payload, 8),
    Cmd = host_game_v1:new(GameId, HostNodeId, MaxPlayers),
    handle(Cmd).

-spec handle(host_game_v1:host_game_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{game_id := GameId, host_node_id := HostNodeId} =
        host_game_v1:to_map(Command),
    case {byte_size(GameId), byte_size(HostNodeId)} of
        {0, _} -> {error, game_id_required};
        {_, 0} -> {error, host_node_id_required};
        _ ->
            CmdMap = host_game_v1:to_map(Command),
            Event = CmdMap#{
                event_type => <<"game_hosted_v1">>,
                hosted_at => erlang:system_time(millisecond)
            },
            {ok, [Event]}
    end.

-spec dispatch(host_game_v1:host_game_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{game_id := GameId} = host_game_v1:to_map(Cmd),
    StreamId = mpong_game_aggregate:stream_id(GameId),
    CmdMap = host_game_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = host_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => host_game},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
