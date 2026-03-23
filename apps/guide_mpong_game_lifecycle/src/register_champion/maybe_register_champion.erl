%%% @doc Handler for register_champion command.
%%% Generates a random champion name + personality if not provided.
-module(maybe_register_champion).

-export([handle_from_map/1, dispatch/0, generate_champion/0]).

-dialyzer({nowarn_function, [dispatch/0]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    NodeId = maps:get(node_id, Payload, <<>>),
    Name = maps:get(name, Payload, <<>>),
    Personality = maps:get(personality, Payload, #{}),
    case byte_size(NodeId) of
        0 -> {error, node_id_required};
        _ ->
            Event = #{
                event_type => <<"champion_registered_v1">>,
                node_id => NodeId,
                name => Name,
                personality => Personality,
                registered_at => erlang:system_time(millisecond)
            },
            {ok, [Event]}
    end.

%% @doc Dispatch a champion registration for this node.
-spec dispatch() -> {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch() ->
    NodeId = atom_to_binary(node()),
    #{name := Name, personality := Personality} = generate_champion(),
    StreamId = mpong_game_aggregate:stream_id(<<"champion-", NodeId/binary>>),
    EvoqCmd = #evoq_command{
        command_type = register_champion,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => register_champion,
            node_id => NodeId,
            name => Name,
            personality => Personality
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

%% @doc Generate a random champion name and personality.
-spec generate_champion() -> #{name := binary(), personality := map()}.
generate_champion() ->
    Adjectives = [<<"Thunder">>, <<"Shadow">>, <<"Iron">>, <<"Cyber">>,
                  <<"Neon">>, <<"Pixel">>, <<"Quantum">>, <<"Blazing">>,
                  <<"Frozen">>, <<"Dark">>, <<"Swift">>, <<"Mighty">>],
    Nouns = [<<"Fist">>, <<"Blade">>, <<"Wall">>, <<"Ghost">>,
             <<"Striker">>, <<"Hawk">>, <<"Viper">>, <<"Storm">>,
             <<"Phoenix">>, <<"Wolf">>, <<"Titan">>, <<"Ace">>],
    Adj = lists:nth(rand:uniform(length(Adjectives)), Adjectives),
    Noun = lists:nth(rand:uniform(length(Nouns)), Nouns),
    Name = <<Adj/binary, Noun/binary>>,

    %% Random personality with balanced stats
    BaseSpeed = 9 + rand:uniform(3),
    BaseErr = 8 + rand:uniform(8),
    Style = rand:uniform(4),
    Personality = case Style of
        1 -> #{style => <<"slicer">>, speed => BaseSpeed,
               bias_range => 30, err_rate => BaseErr,
               err_mag => 30 + rand:uniform(20), aggression => 3 + rand:uniform(2)};
        2 -> #{style => <<"wall">>, speed => BaseSpeed,
               bias_range => 0, err_rate => BaseErr + 2,
               err_mag => 20 + rand:uniform(10), aggression => 3};
        3 -> #{style => <<"gambler">>, speed => BaseSpeed + 1,
               bias_range => 50, err_rate => max(5, BaseErr - 3),
               err_mag => 40 + rand:uniform(30), aggression => 2};
        4 -> #{style => <<"ghost">>, speed => max(8, BaseSpeed - 1),
               bias_range => 0, err_rate => BaseErr + 5,
               err_mag => 15 + rand:uniform(10), aggression => 4 + rand:uniform(2)}
    end,

    #{name => Name, personality => Personality}.
