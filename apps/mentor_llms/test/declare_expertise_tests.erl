%%% @doc Tests for declare_expertise desk
%%% Covers declare_expertise_v1 command validation and
%%% maybe_declare_expertise handler business logic.
-module(declare_expertise_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        agent_id => <<"agent-mentor-1">>,
        domains => [<<"erlang">>, <<"otp">>, <<"event_sourcing">>]
    }.

valid_cmd() ->
    {ok, Cmd} = declare_expertise_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = declare_expertise_v1:new(valid_params()).

missing_domains_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 declare_expertise_v1:new(#{agent_id => <<"a1">>})).

empty_domains_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 declare_expertise_v1:new(#{agent_id => <<"a1">>, domains => []})).

non_binary_domain_rejected_test() ->
    Params = #{agent_id => <<"a1">>, domains => [erlang, otp]},
    ?assertEqual({error, invalid_domains}, declare_expertise_v1:new(Params)).

mixed_valid_invalid_domains_rejected_test() ->
    Params = #{agent_id => <<"a1">>, domains => [<<"erlang">>, 42]},
    ?assertEqual({error, invalid_domains}, declare_expertise_v1:new(Params)).

accessors_return_correct_values_test() ->
    {ok, Cmd} = declare_expertise_v1:new(valid_params()),
    ?assertEqual(<<"agent-mentor-1">>, declare_expertise_v1:get_agent_id(Cmd)),
    ?assertEqual([<<"erlang">>, <<"otp">>, <<"event_sourcing">>],
                 declare_expertise_v1:get_domains(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = declare_expertise_v1:new(valid_params()),
    Map = declare_expertise_v1:to_map(Cmd),
    ?assertEqual(<<"declare_expertise">>, maps:get(command_type, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(agent_id, Map)),
    ?assertEqual([<<"erlang">>, <<"otp">>, <<"event_sourcing">>], maps:get(domains, Map)).

single_domain_accepted_test() ->
    Params = #{agent_id => <<"a1">>, domains => [<<"rust">>]},
    {ok, _Cmd} = declare_expertise_v1:new(Params).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_declare_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_declare_expertise:handle(Cmd),
    Map = expertise_declared_v1:to_map(Event),
    ?assertEqual(<<"expertise_declared_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(agent_id, Map)),
    ?assertEqual([<<"erlang">>, <<"otp">>, <<"event_sourcing">>], maps:get(domains, Map)).

handle_event_has_declared_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_declare_expertise:handle(Cmd),
    DeclaredAt = expertise_declared_v1:get_declared_at(Event),
    ?assert(is_integer(DeclaredAt)),
    ?assert(DeclaredAt > 0).

handle_returns_single_event_test() ->
    Cmd = valid_cmd(),
    {ok, Events} = maybe_declare_expertise:handle(Cmd),
    ?assertEqual(1, length(Events)).
