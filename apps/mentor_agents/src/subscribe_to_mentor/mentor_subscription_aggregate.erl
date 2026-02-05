%%% @doc Mentor subscription aggregate
%%% Maintains subscription state between agents and mentors.
-module(mentor_subscription_aggregate).

-export([execute/2, apply_event/2, initial_state/0]).

-define(SUBSCRIBED,   1).   %% 2^0
-define(UNSUBSCRIBED, 2).   %% 2^1

-record(subscription_state, {
    subscriber_id :: binary() | undefined,
    mentor_id     :: binary() | undefined,
    status        :: non_neg_integer(),
    subscribed_at :: non_neg_integer() | undefined
}).

-type state() :: #subscription_state{}.
-export_type([state/0]).

-spec initial_state() -> state().
initial_state() ->
    #subscription_state{
        subscriber_id = undefined,
        mentor_id = undefined,
        status = 0,
        subscribed_at = undefined
    }.

-spec execute(map(), state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := <<"subscribe_to_mentor">>} = Payload, #subscription_state{status = S}) ->
    case S band ?SUBSCRIBED of
        0 ->
            {ok, Cmd} = subscribe_to_mentor_v1:from_map(Payload),
            convert_events(maybe_subscribe_to_mentor:handle(Cmd), fun mentor_subscribed_v1:to_map/1);
        _ ->
            case S band ?UNSUBSCRIBED of
                0 -> {error, already_subscribed};
                _ ->
                    %% Re-subscribe after unsubscribe
                    {ok, Cmd} = subscribe_to_mentor_v1:from_map(Payload),
                    convert_events(maybe_subscribe_to_mentor:handle(Cmd), fun mentor_subscribed_v1:to_map/1)
            end
    end;
execute(#{command_type := <<"unsubscribe_from_mentor">>} = Payload, #subscription_state{status = S}) ->
    case S band ?SUBSCRIBED of
        0 -> {error, not_subscribed};
        _ ->
            case S band ?UNSUBSCRIBED of
                0 ->
                    {ok, Cmd} = unsubscribe_from_mentor_v1:from_map(Payload),
                    convert_events(maybe_unsubscribe_from_mentor:handle(Cmd), fun mentor_unsubscribed_v1:to_map/1);
                _ ->
                    {error, already_unsubscribed}
            end
    end;
execute(Payload, State) ->
    execute(Payload#{command_type => <<"subscribe_to_mentor">>}, State).

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

-spec apply_event(map(), state()) -> state().
apply_event(#{event_type := <<"mentor_subscribed_v1">>} = E, State) ->
    State#subscription_state{
        subscriber_id = maps:get(subscriber_id, E),
        mentor_id = maps:get(mentor_id, E),
        status = ?SUBSCRIBED,
        subscribed_at = maps:get(subscribed_at, E)
    };
apply_event(#{event_type := <<"mentor_unsubscribed_v1">>} = _E, State) ->
    State#subscription_state{
        status = State#subscription_state.status bor ?UNSUBSCRIBED
    };
apply_event(_E, State) ->
    State.
