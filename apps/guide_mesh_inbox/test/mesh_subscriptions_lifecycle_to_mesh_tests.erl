%%% @doc EUnit tests for mesh_subscriptions_lifecycle_to_mesh.
%%%
%%% Covers the bridge between mesh_subscriptions_store events and the
%%% live `hecate_mesh' substrate calls. `hecate_mesh' is mecked so the
%%% test asserts on subscribe/unsubscribe call counts + args, and the
%%% topic→SubRef map in handler state stays correct under add / remove
%%% / idempotent re-add / unknown-event sequences.
%%% @end
-module(mesh_subscriptions_lifecycle_to_mesh_tests).

-include_lib("eunit/include/eunit.hrl").

-define(MOD, mesh_subscriptions_lifecycle_to_mesh).
-define(T1, <<"chat.demo">>).
-define(T2, <<"agents.module_generated">>).

%%--------------------------------------------------------------------
%% Setup
%%--------------------------------------------------------------------

bridge_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [
        {"init returns an empty topics map",
         fun init_empty/0},
        {"added event triggers hecate_mesh:subscribe and tracks SubRef",
         fun added_triggers_subscribe/0},
        {"second added for same topic is a no-op (no extra subscribe)",
         fun re_added_is_idempotent/0},
        {"removed event triggers hecate_mesh:unsubscribe and drops topic",
         fun removed_triggers_unsubscribe/0},
        {"removed for never-subscribed topic is a no-op",
         fun removed_for_unknown_is_noop/0},
        {"both event shapes accepted: `data` envelope and bare map",
         fun accepts_both_event_shapes/0},
        {"unknown event type is dropped without effect",
         fun unknown_event_is_dropped/0}
     ]}.

setup() ->
    meck:new(hecate_mesh, [non_strict]),
    meck:expect(hecate_mesh, subscribe, 2,
                fun(_Topic, _Cb) -> {ok, make_ref()} end),
    meck:expect(hecate_mesh, unsubscribe, 1, fun(_Ref) -> ok end),
    ok.

cleanup(_) ->
    meck:unload(hecate_mesh),
    ok.

reset_mocks() ->
    meck:reset(hecate_mesh).

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

init_empty() ->
    {ok, S} = ?MOD:init(#{}),
    ?assertEqual(#{topics => #{}}, S).

added_triggers_subscribe() ->
    reset_mocks(),
    {ok, S0} = ?MOD:init(#{}),
    {ok, S1} = ?MOD:handle_event(<<"mesh_subscription_added_v1">>,
                                 #{data => #{topic => ?T1}}, #{}, S0),
    ?assertEqual(1, meck:num_calls(hecate_mesh, subscribe, 2)),
    ?assert(maps:is_key(?T1, maps:get(topics, S1))),
    %% A second distinct topic adds another subscribe.
    {ok, S2} = ?MOD:handle_event(<<"mesh_subscription_added_v1">>,
                                 #{data => #{topic => ?T2}}, #{}, S1),
    ?assertEqual(2, meck:num_calls(hecate_mesh, subscribe, 2)),
    ?assertEqual(2, map_size(maps:get(topics, S2))).

re_added_is_idempotent() ->
    reset_mocks(),
    {ok, S0} = ?MOD:init(#{}),
    {ok, S1} = ?MOD:handle_event(<<"mesh_subscription_added_v1">>,
                                 #{data => #{topic => ?T1}}, #{}, S0),
    {ok, S2} = ?MOD:handle_event(<<"mesh_subscription_added_v1">>,
                                 #{data => #{topic => ?T1}}, #{}, S1),
    ?assertEqual(1, meck:num_calls(hecate_mesh, subscribe, 2)),
    ?assertEqual(S1, S2).

removed_triggers_unsubscribe() ->
    reset_mocks(),
    {ok, S0} = ?MOD:init(#{}),
    {ok, S1} = ?MOD:handle_event(<<"mesh_subscription_added_v1">>,
                                 #{data => #{topic => ?T1}}, #{}, S0),
    {ok, S2} = ?MOD:handle_event(<<"mesh_subscription_removed_v1">>,
                                 #{data => #{topic => ?T1}}, #{}, S1),
    ?assertEqual(1, meck:num_calls(hecate_mesh, unsubscribe, 1)),
    ?assertNot(maps:is_key(?T1, maps:get(topics, S2))),
    ?assertEqual(#{topics => #{}}, S2).

removed_for_unknown_is_noop() ->
    reset_mocks(),
    {ok, S0} = ?MOD:init(#{}),
    {ok, S1} = ?MOD:handle_event(<<"mesh_subscription_removed_v1">>,
                                 #{data => #{topic => ?T1}}, #{}, S0),
    ?assertEqual(0, meck:num_calls(hecate_mesh, unsubscribe, 1)),
    ?assertEqual(S0, S1).

accepts_both_event_shapes() ->
    reset_mocks(),
    {ok, S0} = ?MOD:init(#{}),
    %% Shape 1: top-level topic key (no `data` envelope).
    {ok, S1} = ?MOD:handle_event(<<"mesh_subscription_added_v1">>,
                                 #{topic => ?T1}, #{}, S0),
    %% Shape 2: nested under data (matches the projection's view of the
    %% stored event).
    {ok, S2} = ?MOD:handle_event(<<"mesh_subscription_added_v1">>,
                                 #{data => #{topic => ?T2}}, #{}, S1),
    ?assertEqual(2, meck:num_calls(hecate_mesh, subscribe, 2)),
    ?assertEqual(2, map_size(maps:get(topics, S2))).

unknown_event_is_dropped() ->
    reset_mocks(),
    {ok, S0} = ?MOD:init(#{}),
    {ok, S1} = ?MOD:handle_event(<<"unrelated_event_v1">>,
                                 #{topic => ?T1}, #{}, S0),
    ?assertEqual(0, meck:num_calls(hecate_mesh, subscribe, 2)),
    ?assertEqual(0, meck:num_calls(hecate_mesh, unsubscribe, 1)),
    ?assertEqual(S0, S1).
