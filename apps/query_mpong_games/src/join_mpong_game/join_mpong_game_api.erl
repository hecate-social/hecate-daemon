%%%-------------------------------------------------------------------
%%% @doc POST /api/mpong/games/:game_id/join — join an existing game.
%%% @end
%%%-------------------------------------------------------------------
-module(join_mpong_game_api).

-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/mpong/games/:game_id/join", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"method_not_allowed">>}),
                Req0),
            {ok, Req, State}
    end.

handle_post(Req0, State) ->
    GameId = cowboy_req:binding(game_id, Req0),
    PlayerNodeId = atom_to_binary(node()),

    StreamId = mpong_game_aggregate:stream_id(GameId),
    EvoqCmd = #evoq_command{
        command_type = join_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => join_game,
            game_id => GameId,
            player_node_id => PlayerNodeId
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    case evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }) of
        {ok, _V, _Events} ->
            Resp = json:encode(#{ok => true, game_id => GameId, player_node_id => PlayerNodeId}),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Resp, Req0),
            {ok, Req, State};
        {error, Reason} ->
            Resp = json:encode(#{ok => false, error => atom_to_binary(Reason)}),
            Req = cowboy_req:reply(400,
                #{<<"content-type">> => <<"application/json">>},
                Resp, Req0),
            {ok, Req, State}
    end.
