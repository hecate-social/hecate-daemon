%%% @doc Mentor profile aggregate
%%% Maintains mentor profile state (expertise declarations).
-module(mentor_profile_aggregate).

-export([execute/2, apply_event/2, initial_state/0]).

-define(ACTIVE,    1).   %% 2^0
-define(WITHDRAWN, 2).   %% 2^1

-record(mentor_profile_state, {
    agent_id    :: binary() | undefined,
    domains     :: [binary()],
    status      :: non_neg_integer(),
    declared_at :: non_neg_integer() | undefined
}).

-type state() :: #mentor_profile_state{}.
-export_type([state/0]).

-spec initial_state() -> state().
initial_state() ->
    #mentor_profile_state{
        agent_id = undefined,
        domains = [],
        status = 0,
        declared_at = undefined
    }.

-spec execute(map(), state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := <<"declare_expertise">>} = Payload, _State) ->
    {ok, Cmd} = declare_expertise_v1:from_map(Payload),
    convert_events(maybe_declare_expertise:handle(Cmd), fun expertise_declared_v1:to_map/1);
execute(#{command_type := <<"withdraw_expertise">>} = Payload, State) ->
    case State#mentor_profile_state.agent_id of
        undefined ->
            {error, profile_not_found};
        _ ->
            case State#mentor_profile_state.status band ?WITHDRAWN of
                0 ->
                    {ok, Cmd} = withdraw_expertise_v1:from_map(Payload),
                    convert_events(maybe_withdraw_expertise:handle(Cmd), fun expertise_withdrawn_v1:to_map/1);
                _ ->
                    {error, already_withdrawn}
            end
    end;
execute(Payload, State) ->
    execute(Payload#{command_type => <<"declare_expertise">>}, State).

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

-spec apply_event(map(), state()) -> state().
apply_event(#{event_type := <<"expertise_declared_v1">>} = E, State) ->
    State#mentor_profile_state{
        agent_id = maps:get(agent_id, E),
        domains = maps:get(domains, E, []),
        status = ?ACTIVE,
        declared_at = maps:get(declared_at, E)
    };
apply_event(#{event_type := <<"expertise_withdrawn_v1">>} = _E, State) ->
    State#mentor_profile_state{
        status = State#mentor_profile_state.status bor ?WITHDRAWN
    };
apply_event(_E, State) ->
    State.
