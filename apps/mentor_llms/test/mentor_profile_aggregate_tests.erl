%%% @doc Tests for mentor_profile_aggregate module.
-module(mentor_profile_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

-record(mentor_profile_state, {
    agent_id    :: binary() | undefined,
    domains     :: [binary()],
    status      :: non_neg_integer(),
    declared_at :: non_neg_integer() | undefined
}).

-define(ACTIVE,    1).
-define(WITHDRAWN, 2).

%%% ===================================================================
%%% Helpers
%%% ===================================================================

declare_payload() ->
    #{command_type => <<"declare_expertise">>,
      agent_id => <<"agent-1">>,
      domains => [<<"erlang">>, <<"otp">>]}.

withdraw_payload() ->
    #{command_type => <<"withdraw_expertise">>,
      agent_id => <<"agent-1">>}.

%%% ===================================================================
%%% Tests
%%% ===================================================================

initial_state_test() ->
    State = mentor_profile_aggregate:initial_state(),
    ?assertEqual(undefined, State#mentor_profile_state.agent_id),
    ?assertEqual([], State#mentor_profile_state.domains),
    ?assertEqual(0, State#mentor_profile_state.status),
    ?assertEqual(undefined, State#mentor_profile_state.declared_at).

execute_declare_expertise_test() ->
    State = mentor_profile_aggregate:initial_state(),
    Payload = declare_payload(),
    {ok, [EventMap]} = mentor_profile_aggregate:execute(State, Payload),
    ?assertEqual(<<"expertise_declared_v1">>, maps:get(event_type, EventMap)),
    ?assertEqual(<<"agent-1">>, maps:get(agent_id, EventMap)),
    ?assertEqual([<<"erlang">>, <<"otp">>], maps:get(domains, EventMap)),
    ?assert(is_integer(maps:get(declared_at, EventMap))).

apply_expertise_declared_v1_test() ->
    State0 = mentor_profile_aggregate:initial_state(),
    EventMap = #{
        event_type => <<"expertise_declared_v1">>,
        agent_id => <<"agent-1">>,
        domains => [<<"erlang">>, <<"otp">>],
        declared_at => 1700000000000
    },
    State1 = mentor_profile_aggregate:apply(State0, EventMap),
    ?assertEqual(<<"agent-1">>, State1#mentor_profile_state.agent_id),
    ?assertEqual([<<"erlang">>, <<"otp">>], State1#mentor_profile_state.domains),
    ?assertEqual(?ACTIVE, State1#mentor_profile_state.status),
    ?assertEqual(1700000000000, State1#mentor_profile_state.declared_at).

execute_withdraw_expertise_test() ->
    %% Build an ACTIVE state by applying the declared event
    State0 = mentor_profile_aggregate:initial_state(),
    DeclaredEvent = #{
        event_type => <<"expertise_declared_v1">>,
        agent_id => <<"agent-1">>,
        domains => [<<"erlang">>, <<"otp">>],
        declared_at => 1700000000000
    },
    State1 = mentor_profile_aggregate:apply(State0, DeclaredEvent),
    ?assertEqual(?ACTIVE, State1#mentor_profile_state.status),
    %% Now withdraw
    {ok, [EventMap]} = mentor_profile_aggregate:execute(State1, withdraw_payload()),
    ?assertEqual(<<"expertise_withdrawn_v1">>, maps:get(event_type, EventMap)).

execute_withdraw_on_fresh_state_test() ->
    State = mentor_profile_aggregate:initial_state(),
    ?assertEqual({error, profile_not_found},
                 mentor_profile_aggregate:execute(State, withdraw_payload())).

execute_withdraw_already_withdrawn_test() ->
    %% Build state: declared then withdrawn
    State0 = mentor_profile_aggregate:initial_state(),
    DeclaredEvent = #{
        event_type => <<"expertise_declared_v1">>,
        agent_id => <<"agent-1">>,
        domains => [<<"erlang">>, <<"otp">>],
        declared_at => 1700000000000
    },
    WithdrawnEvent = #{
        event_type => <<"expertise_withdrawn_v1">>,
        agent_id => <<"agent-1">>,
        withdrawn_at => 1700000001000
    },
    State1 = mentor_profile_aggregate:apply(State0, DeclaredEvent),
    State2 = mentor_profile_aggregate:apply(State1, WithdrawnEvent),
    ?assertEqual({error, already_withdrawn},
                 mentor_profile_aggregate:execute(State2, withdraw_payload())).

apply_expertise_withdrawn_v1_test() ->
    %% Start with an ACTIVE state
    State0 = mentor_profile_aggregate:initial_state(),
    DeclaredEvent = #{
        event_type => <<"expertise_declared_v1">>,
        agent_id => <<"agent-1">>,
        domains => [<<"erlang">>, <<"otp">>],
        declared_at => 1700000000000
    },
    State1 = mentor_profile_aggregate:apply(State0, DeclaredEvent),
    ?assertEqual(?ACTIVE, State1#mentor_profile_state.status),
    %% Apply withdrawn event
    WithdrawnEvent = #{
        event_type => <<"expertise_withdrawn_v1">>,
        agent_id => <<"agent-1">>,
        withdrawn_at => 1700000001000
    },
    State2 = mentor_profile_aggregate:apply(State1, WithdrawnEvent),
    %% ACTIVE bor WITHDRAWN = 1 bor 2 = 3
    ?assertEqual(?ACTIVE bor ?WITHDRAWN, State2#mentor_profile_state.status),
    ?assertEqual(3, State2#mentor_profile_state.status).
