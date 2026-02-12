%%% @doc Tests for withdraw_expertise desk
%%% Covers withdraw_expertise_v1 command validation and
%%% maybe_withdraw_expertise handler business logic.
-module(withdraw_expertise_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{agent_id => <<"agent-mentor-1">>}.

valid_cmd() ->
    {ok, Cmd} = withdraw_expertise_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = withdraw_expertise_v1:new(valid_params()).

accessor_returns_correct_value_test() ->
    {ok, Cmd} = withdraw_expertise_v1:new(valid_params()),
    ?assertEqual(<<"agent-mentor-1">>, withdraw_expertise_v1:get_agent_id(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = withdraw_expertise_v1:new(valid_params()),
    Map = withdraw_expertise_v1:to_map(Cmd),
    ?assertEqual(<<"withdraw_expertise">>, maps:get(command_type, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(agent_id, Map)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_withdraw_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_withdraw_expertise:handle(Cmd),
    Map = expertise_withdrawn_v1:to_map(Event),
    ?assertEqual(<<"expertise_withdrawn_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(agent_id, Map)).

handle_event_has_withdrawn_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_withdraw_expertise:handle(Cmd),
    WithdrawnAt = expertise_withdrawn_v1:get_withdrawn_at(Event),
    ?assert(is_integer(WithdrawnAt)),
    ?assert(WithdrawnAt > 0).

handle_returns_single_event_test() ->
    Cmd = valid_cmd(),
    {ok, Events} = maybe_withdraw_expertise:handle(Cmd),
    ?assertEqual(1, length(Events)).
