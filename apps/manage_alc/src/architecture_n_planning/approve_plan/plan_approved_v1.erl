%%% @doc plan_approved_v1 event
%%% Emitted when a plan is approved during architecture and planning.
-module(plan_approved_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_plan_id/1, get_approved_at/1]).

-record(plan_approved_v1, {
    project_id  :: binary(),
    plan_id     :: binary(),
    approved_at :: integer()
}).

-export_type([plan_approved_v1/0]).
-opaque plan_approved_v1() :: #plan_approved_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plan_approved_v1().
new(#{project_id := ProjectId, plan_id := PlanId} = _Params) ->
    #plan_approved_v1{
        project_id = ProjectId,
        plan_id = PlanId,
        approved_at = erlang:system_time(millisecond)
    }.

-spec to_map(plan_approved_v1()) -> map().
to_map(#plan_approved_v1{} = E) ->
    #{
        event_type => <<"plan_approved_v1">>,
        project_id => E#plan_approved_v1.project_id,
        plan_id => E#plan_approved_v1.plan_id,
        approved_at => E#plan_approved_v1.approved_at
    }.

-spec from_map(map()) -> {ok, plan_approved_v1()} | {error, term()}.
from_map(#{project_id := ProjectId, plan_id := PlanId} = Map) ->
    {ok, #plan_approved_v1{
        project_id = ProjectId,
        plan_id = PlanId,
        approved_at = maps:get(approved_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#plan_approved_v1{project_id = V}) -> V.
get_plan_id(#plan_approved_v1{plan_id = V}) -> V.
get_approved_at(#plan_approved_v1{approved_at = V}) -> V.
