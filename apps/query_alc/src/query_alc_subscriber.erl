%%% @doc Event subscriber for query_alc projections.
%%% Subscribes to manage_alc_store events and projects to SQLite.
-module(query_alc_subscriber).
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
        manage_alc_store,
        all,
        <<"*">>,
        <<"query_alc_subscriber">>,
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
        _ -> reckon_evoq_adapter:unsubscribe(manage_alc_store, SubId)
    end.

%% Internal

project_event(#{event_type := <<"project_initiated_v1">>} = E, State) ->
    safe_project(fun() -> project_initiated_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"discovery_started_v1">>} = E, State) ->
    safe_project(fun() -> discovery_started_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"finding_recorded_v1">>} = E, State) ->
    safe_project(fun() -> finding_recorded_v1_to_findings:project(E) end, State);
project_event(#{event_type := <<"term_defined_v1">>} = E, State) ->
    safe_project(fun() -> term_defined_v1_to_terms:project(E) end, State);
project_event(#{event_type := <<"discovery_completed_v1">>} = E, State) ->
    safe_project(fun() -> discovery_completed_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"phase_transitioned_v1">>} = E, State) ->
    safe_project(fun() -> phase_transitioned_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"architecture_started_v1">>} = E, State) ->
    safe_project(fun() -> architecture_started_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"dossier_defined_v1">>} = E, State) ->
    safe_project(fun() -> dossier_defined_v1_to_dossier_designs:project(E) end, State);
project_event(#{event_type := <<"spoke_inventoried_v1">>} = E, State) ->
    safe_project(fun() -> spoke_inventoried_v1_to_spoke_inventory:project(E) end, State);
project_event(#{event_type := <<"plan_drafted_v1">>} = E, State) ->
    safe_project(fun() -> plan_drafted_v1_to_plans:project(E) end, State);
project_event(#{event_type := <<"plan_approved_v1">>} = E, State) ->
    safe_project(fun() -> plan_approved_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"architecture_completed_v1">>} = E, State) ->
    safe_project(fun() -> architecture_completed_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"testing_started_v1">>} = E, State) ->
    safe_project(fun() -> testing_started_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"skeleton_created_v1">>} = E, State) ->
    safe_project(fun() -> skeleton_created_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"spoke_implemented_v1">>} = E, State) ->
    safe_project(fun() -> spoke_implemented_v1_to_spoke_implementations:project(E) end, State);
project_event(#{event_type := <<"build_verified_v1">>} = E, State) ->
    safe_project(fun() -> build_verified_v1_to_build_verifications:project(E) end, State);
project_event(#{event_type := <<"testing_completed_v1">>} = E, State) ->
    safe_project(fun() -> testing_completed_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"deployment_started_v1">>} = E, State) ->
    safe_project(fun() -> deployment_started_v1_to_projects:project(E) end, State);
project_event(#{event_type := <<"deployment_recorded_v1">>} = E, State) ->
    safe_project(fun() -> deployment_recorded_v1_to_deployments:project(E) end, State);
project_event(#{event_type := <<"incident_reported_v1">>} = E, State) ->
    safe_project(fun() -> incident_reported_v1_to_incidents:project(E) end, State);
project_event(#{event_type := <<"incident_resolved_v1">>} = E, State) ->
    safe_project(fun() -> incident_resolved_v1_to_incidents:project(E) end, State);
project_event(#{event_type := <<"deployment_completed_v1">>} = E, State) ->
    safe_project(fun() -> deployment_completed_v1_to_projects:project(E) end, State);
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
