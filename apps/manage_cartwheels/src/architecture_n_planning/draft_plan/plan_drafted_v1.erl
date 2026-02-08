%%% @doc plan_drafted_v1 event
%%% Emitted when a plan is drafted during architecture and planning.
-module(plan_drafted_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_plan_id/1, get_title/1,
         get_content_ref/1, get_drafted_at/1]).

-record(plan_drafted_v1, {
    cartwheel_id  :: binary(),
    plan_id     :: binary(),
    title       :: binary(),
    content_ref :: binary() | undefined,
    drafted_at  :: integer()
}).

-export_type([plan_drafted_v1/0]).
-opaque plan_drafted_v1() :: #plan_drafted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plan_drafted_v1().
new(#{cartwheel_id := CartwheelId, plan_id := PlanId, title := Title} = Params) ->
    #plan_drafted_v1{
        cartwheel_id = CartwheelId,
        plan_id = PlanId,
        title = Title,
        content_ref = maps:get(content_ref, Params, undefined),
        drafted_at = erlang:system_time(millisecond)
    }.

-spec to_map(plan_drafted_v1()) -> map().
to_map(#plan_drafted_v1{} = E) ->
    #{
        event_type => <<"plan_drafted_v1">>,
        cartwheel_id => E#plan_drafted_v1.cartwheel_id,
        plan_id => E#plan_drafted_v1.plan_id,
        title => E#plan_drafted_v1.title,
        content_ref => E#plan_drafted_v1.content_ref,
        drafted_at => E#plan_drafted_v1.drafted_at
    }.

-spec from_map(map()) -> {ok, plan_drafted_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId, plan_id := PlanId, title := Title} = Map) ->
    {ok, #plan_drafted_v1{
        cartwheel_id = CartwheelId,
        plan_id = PlanId,
        title = Title,
        content_ref = maps:get(content_ref, Map, undefined),
        drafted_at = maps:get(drafted_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#plan_drafted_v1{cartwheel_id = V}) -> V.
get_plan_id(#plan_drafted_v1{plan_id = V}) -> V.
get_title(#plan_drafted_v1{title = V}) -> V.
get_content_ref(#plan_drafted_v1{content_ref = V}) -> V.
get_drafted_at(#plan_drafted_v1{drafted_at = V}) -> V.
