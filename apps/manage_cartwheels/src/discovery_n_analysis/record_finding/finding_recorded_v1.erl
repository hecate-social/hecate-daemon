%%% @doc finding_recorded_v1 event
%%% Emitted when a finding is recorded during discovery.
-module(finding_recorded_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_finding_id/1, get_category/1,
         get_title/1, get_content/1, get_priority/1, get_recorded_at/1]).

-record(finding_recorded_v1, {
    cartwheel_id  :: binary(),
    finding_id  :: binary(),
    category    :: binary(),
    title       :: binary(),
    content     :: binary() | undefined,
    priority    :: binary(),
    recorded_at :: integer()
}).

-export_type([finding_recorded_v1/0]).
-opaque finding_recorded_v1() :: #finding_recorded_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> finding_recorded_v1().
new(#{cartwheel_id := CartwheelId, finding_id := FindingId, category := Category,
      title := Title} = Params) ->
    #finding_recorded_v1{
        cartwheel_id = CartwheelId,
        finding_id = FindingId,
        category = Category,
        title = Title,
        content = maps:get(content, Params, undefined),
        priority = maps:get(priority, Params, <<"should">>),
        recorded_at = erlang:system_time(millisecond)
    }.

-spec to_map(finding_recorded_v1()) -> map().
to_map(#finding_recorded_v1{} = E) ->
    #{
        event_type => <<"finding_recorded_v1">>,
        cartwheel_id => E#finding_recorded_v1.cartwheel_id,
        finding_id => E#finding_recorded_v1.finding_id,
        category => E#finding_recorded_v1.category,
        title => E#finding_recorded_v1.title,
        content => E#finding_recorded_v1.content,
        priority => E#finding_recorded_v1.priority,
        recorded_at => E#finding_recorded_v1.recorded_at
    }.

-spec from_map(map()) -> {ok, finding_recorded_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId, finding_id := FindingId,
           category := Category, title := Title} = Map) ->
    {ok, #finding_recorded_v1{
        cartwheel_id = CartwheelId,
        finding_id = FindingId,
        category = Category,
        title = Title,
        content = maps:get(content, Map, undefined),
        priority = maps:get(priority, Map, <<"should">>),
        recorded_at = maps:get(recorded_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#finding_recorded_v1{cartwheel_id = V}) -> V.
get_finding_id(#finding_recorded_v1{finding_id = V}) -> V.
get_category(#finding_recorded_v1{category = V}) -> V.
get_title(#finding_recorded_v1{title = V}) -> V.
get_content(#finding_recorded_v1{content = V}) -> V.
get_priority(#finding_recorded_v1{priority = V}) -> V.
get_recorded_at(#finding_recorded_v1{recorded_at = V}) -> V.
