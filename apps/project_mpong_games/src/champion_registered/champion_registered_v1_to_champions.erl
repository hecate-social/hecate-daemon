%%%-------------------------------------------------------------------
%%% @doc Projection: champion_registered_v1 -> mpong_champions ETS table.
%%% @end
%%%-------------------------------------------------------------------
-module(champion_registered_v1_to_champions).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

interested_in() -> [<<"champion_registered_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => mpong_champions}),
    {ok, #{}, RM}.

project(#{data := Data} = _Event, _Metadata, State, RM) ->
    NodeId = gf(node_id, Data),
    Champion = #{
        node_id => NodeId,
        name => gf(name, Data),
        personality => gf(personality, Data),
        registered_at => gf(registered_at, Data),
        wins => 0,
        losses => 0,
        games_played => 0
    },
    {ok, RM2} = evoq_read_model:put(NodeId, Champion, RM),
    {ok, State, RM2};
project(_Event, _Metadata, State, RM) ->
    {ok, State, RM}.

gf(Key, Data) when is_atom(Key) ->
    BinKey = atom_to_binary(Key),
    case maps:find(Key, Data) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Data) of
                {ok, V} -> V;
                error -> undefined
            end
    end.
