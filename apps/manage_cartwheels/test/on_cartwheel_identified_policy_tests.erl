%%% @doc Tests for on_cartwheel_identified_maybe_initiate_cartwheel policy
%%%
%%% Tests the policy that reacts to cartwheel_identified facts
%%% and initiates cartwheels via command dispatch.
-module(on_cartwheel_identified_policy_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test that policy correctly extracts fields from binary-keyed map
extract_fields_binary_keys_test() ->
    %% Event with binary keys (as produced by cartwheel_identified_v1:to_map/1)
    FactData = #{
        <<"event_type">> => <<"cartwheel_identified_v1">>,
        <<"torch_id">> => <<"torch-123">>,
        <<"cartwheel_id">> => <<"cw-456">>,
        <<"context_name">> => <<"My Context">>,
        <<"description">> => <<"Test description">>
    },

    %% Verify get_field works with binary keys
    ?assertEqual(<<"torch-123">>, get_field(torch_id, FactData)),
    ?assertEqual(<<"cw-456">>, get_field(cartwheel_id, FactData)),
    ?assertEqual(<<"My Context">>, get_field(context_name, FactData)),
    ?assertEqual(<<"Test description">>, get_field(description, FactData)).

%% Test that policy correctly extracts fields from atom-keyed map
extract_fields_atom_keys_test() ->
    %% Event with atom keys
    FactData = #{
        torch_id => <<"torch-123">>,
        cartwheel_id => <<"cw-456">>,
        context_name => <<"My Context">>,
        description => <<"Test description">>
    },

    ?assertEqual(<<"torch-123">>, get_field(torch_id, FactData)),
    ?assertEqual(<<"cw-456">>, get_field(cartwheel_id, FactData)),
    ?assertEqual(<<"My Context">>, get_field(context_name, FactData)),
    ?assertEqual(<<"Test description">>, get_field(description, FactData)).

%% Test that missing fields return undefined
extract_missing_fields_test() ->
    FactData = #{
        <<"torch_id">> => <<"torch-123">>
    },

    ?assertEqual(<<"torch-123">>, get_field(torch_id, FactData)),
    ?assertEqual(undefined, get_field(cartwheel_id, FactData)),
    ?assertEqual(undefined, get_field(context_name, FactData)).

%% Test that initiate_cartwheel_v1:new/1 works with atom-keyed map
command_creation_test() ->
    Params = #{
        cartwheel_id => <<"cw-test-123">>,
        torch_id => <<"torch-456">>,
        context_name => <<"Test Context">>,
        description => <<"A test">>
    },

    Result = initiate_cartwheel_v1:new(Params),
    ?assertMatch({ok, _}, Result),

    {ok, Cmd} = Result,
    ?assertEqual(<<"cw-test-123">>, initiate_cartwheel_v1:get_cartwheel_id(Cmd)),
    ?assertEqual(<<"torch-456">>, initiate_cartwheel_v1:get_torch_id(Cmd)),
    ?assertEqual(<<"Test Context">>, initiate_cartwheel_v1:get_context_name(Cmd)).

%% Test that command creation fails with missing context_name
command_creation_missing_context_test() ->
    Params = #{
        cartwheel_id => <<"cw-test-123">>,
        torch_id => <<"torch-456">>
        %% context_name is missing!
    },

    Result = initiate_cartwheel_v1:new(Params),
    ?assertMatch({error, _}, Result).

%% Test that command creation works with undefined description
command_creation_undefined_description_test() ->
    Params = #{
        cartwheel_id => <<"cw-test-123">>,
        torch_id => <<"torch-456">>,
        context_name => <<"Test Context">>,
        description => undefined
    },

    Result = initiate_cartwheel_v1:new(Params),
    ?assertMatch({ok, _}, Result),

    {ok, Cmd} = Result,
    ?assertEqual(undefined, initiate_cartwheel_v1:get_description(Cmd)).

%% Internal helper (copied from policy module for testing)
get_field(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    maps:get(Key, Map, maps:get(BinKey, Map, undefined)).
