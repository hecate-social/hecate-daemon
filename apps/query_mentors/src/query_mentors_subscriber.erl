%%% @doc Event subscriber for query_mentors projections.
%%% Subscribes to mentor_agents_store events and projects to SQLite.
-module(query_mentors_subscriber).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [init/1, terminate/2]}).

-record(state, {
    subscription_id :: binary() | undefined,
    event_count :: non_neg_integer(),
    error_count :: non_neg_integer()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, SubId} = reckon_evoq_adapter:subscribe(
        mentor_agents_store,
        all,
        <<"*">>,
        <<"query_mentors_subscriber">>,
        #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId, event_count = 0, error_count = 0}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{data = EventData} = _Event}, State) ->
    NewState = project_event(EventData, State),
    {noreply, NewState};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> reckon_evoq_adapter:unsubscribe(mentor_agents_store, SubId)
    end.

%% Internal

project_event(#{event_type := <<"learning_submitted_v1">>} = E, State) ->
    safe_project(fun() -> learning_submitted_v1_to_learnings:project(E) end, State);
project_event(#{event_type := <<"learning_validated_v1">>} = E, State) ->
    safe_project(fun() -> learning_validated_v1_to_learnings:project(E) end, State);
project_event(#{event_type := <<"learning_rejected_v1">>} = E, State) ->
    safe_project(fun() -> learning_rejected_v1_to_learnings:project(E) end, State);
project_event(#{event_type := <<"learning_endorsed_v1">>} = E, State) ->
    safe_project(fun() -> learning_endorsed_v1_to_learnings:project(E) end, State);
project_event(#{event_type := <<"learning_disputed_v1">>} = E, State) ->
    safe_project(fun() -> learning_disputed_v1_to_learnings:project(E) end, State);
project_event(#{event_type := <<"dispute_resolved_v1">>} = E, State) ->
    safe_project(fun() -> dispute_resolved_v1_to_learnings:project(E) end, State);
project_event(#{event_type := <<"mentor_subscribed_v1">>} = E, State) ->
    safe_project(fun() -> mentor_subscribed_v1_to_subscriptions:project(E) end, State);
project_event(#{event_type := <<"mentor_unsubscribed_v1">>} = E, State) ->
    safe_project(fun() -> mentor_unsubscribed_v1_to_subscriptions:project(E) end, State);
project_event(#{event_type := <<"expertise_declared_v1">>} = E, State) ->
    safe_project(fun() -> expertise_declared_v1_to_profiles:project(E) end, State);
project_event(#{event_type := <<"expertise_withdrawn_v1">>} = E, State) ->
    safe_project(fun() -> expertise_withdrawn_v1_to_profiles:project(E) end, State);
project_event(_Unknown, State) ->
    State.

safe_project(Fun, #state{event_count = EC, error_count = ErrC} = State) ->
    try
        Fun(),
        State#state{event_count = EC + 1}
    catch
        Class:Reason:Stack ->
            logger:error("Projection error: ~p:~p~n~p", [Class, Reason, Stack]),
            State#state{error_count = ErrC + 1}
    end.
