%%% @doc spoke_implemented_v1 event
%%% Emitted when a spoke is implemented during testing and implementation.
-module(spoke_implemented_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_implementation_id/1, get_spoke_id/1,
         get_implementation_notes/1, get_implemented_at/1]).

-record(spoke_implemented_v1, {
    project_id           :: binary(),
    implementation_id    :: binary(),
    spoke_id             :: binary(),
    implementation_notes :: binary() | undefined,
    implemented_at       :: integer()
}).

-export_type([spoke_implemented_v1/0]).
-opaque spoke_implemented_v1() :: #spoke_implemented_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> spoke_implemented_v1().
new(#{project_id := ProjectId, implementation_id := ImplementationId,
      spoke_id := SpokeId} = Params) ->
    #spoke_implemented_v1{
        project_id = ProjectId,
        implementation_id = ImplementationId,
        spoke_id = SpokeId,
        implementation_notes = maps:get(implementation_notes, Params, undefined),
        implemented_at = erlang:system_time(millisecond)
    }.

-spec to_map(spoke_implemented_v1()) -> map().
to_map(#spoke_implemented_v1{} = E) ->
    #{
        event_type => <<"spoke_implemented_v1">>,
        project_id => E#spoke_implemented_v1.project_id,
        implementation_id => E#spoke_implemented_v1.implementation_id,
        spoke_id => E#spoke_implemented_v1.spoke_id,
        implementation_notes => E#spoke_implemented_v1.implementation_notes,
        implemented_at => E#spoke_implemented_v1.implemented_at
    }.

-spec from_map(map()) -> {ok, spoke_implemented_v1()} | {error, term()}.
from_map(#{project_id := ProjectId, implementation_id := ImplementationId,
           spoke_id := SpokeId} = Map) ->
    {ok, #spoke_implemented_v1{
        project_id = ProjectId,
        implementation_id = ImplementationId,
        spoke_id = SpokeId,
        implementation_notes = maps:get(implementation_notes, Map, undefined),
        implemented_at = maps:get(implemented_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#spoke_implemented_v1{project_id = V}) -> V.
get_implementation_id(#spoke_implemented_v1{implementation_id = V}) -> V.
get_spoke_id(#spoke_implemented_v1{spoke_id = V}) -> V.
get_implementation_notes(#spoke_implemented_v1{implementation_notes = V}) -> V.
get_implemented_at(#spoke_implemented_v1{implemented_at = V}) -> V.
