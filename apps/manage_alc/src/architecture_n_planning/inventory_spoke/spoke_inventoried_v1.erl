%%% @doc spoke_inventoried_v1 event
%%% Emitted when a spoke is inventoried within a dossier.
-module(spoke_inventoried_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_spoke_id/1, get_spoke_name/1, get_spoke_type/1,
         get_priority/1, get_dossier_id/1, get_description/1, get_inventoried_at/1]).

-record(spoke_inventoried_v1, {
    project_id     :: binary(),
    spoke_id       :: binary(),
    spoke_name     :: binary(),
    spoke_type     :: binary(),
    priority       :: binary(),
    dossier_id     :: binary(),
    description    :: binary() | undefined,
    inventoried_at :: integer()
}).

-export_type([spoke_inventoried_v1/0]).
-opaque spoke_inventoried_v1() :: #spoke_inventoried_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> spoke_inventoried_v1().
new(#{project_id := ProjectId, spoke_id := SpokeId, spoke_name := SpokeName,
      spoke_type := SpokeType, dossier_id := DossierId} = Params) ->
    #spoke_inventoried_v1{
        project_id = ProjectId,
        spoke_id = SpokeId,
        spoke_name = SpokeName,
        spoke_type = SpokeType,
        priority = maps:get(priority, Params, <<"should">>),
        dossier_id = DossierId,
        description = maps:get(description, Params, undefined),
        inventoried_at = erlang:system_time(millisecond)
    }.

-spec to_map(spoke_inventoried_v1()) -> map().
to_map(#spoke_inventoried_v1{} = E) ->
    #{
        event_type => <<"spoke_inventoried_v1">>,
        project_id => E#spoke_inventoried_v1.project_id,
        spoke_id => E#spoke_inventoried_v1.spoke_id,
        spoke_name => E#spoke_inventoried_v1.spoke_name,
        spoke_type => E#spoke_inventoried_v1.spoke_type,
        priority => E#spoke_inventoried_v1.priority,
        dossier_id => E#spoke_inventoried_v1.dossier_id,
        description => E#spoke_inventoried_v1.description,
        inventoried_at => E#spoke_inventoried_v1.inventoried_at
    }.

-spec from_map(map()) -> {ok, spoke_inventoried_v1()} | {error, term()}.
from_map(#{project_id := ProjectId, spoke_id := SpokeId, spoke_name := SpokeName,
           spoke_type := SpokeType, dossier_id := DossierId} = Map) ->
    {ok, #spoke_inventoried_v1{
        project_id = ProjectId,
        spoke_id = SpokeId,
        spoke_name = SpokeName,
        spoke_type = SpokeType,
        priority = maps:get(priority, Map, <<"should">>),
        dossier_id = DossierId,
        description = maps:get(description, Map, undefined),
        inventoried_at = maps:get(inventoried_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#spoke_inventoried_v1{project_id = V}) -> V.
get_spoke_id(#spoke_inventoried_v1{spoke_id = V}) -> V.
get_spoke_name(#spoke_inventoried_v1{spoke_name = V}) -> V.
get_spoke_type(#spoke_inventoried_v1{spoke_type = V}) -> V.
get_priority(#spoke_inventoried_v1{priority = V}) -> V.
get_dossier_id(#spoke_inventoried_v1{dossier_id = V}) -> V.
get_description(#spoke_inventoried_v1{description = V}) -> V.
get_inventoried_at(#spoke_inventoried_v1{inventoried_at = V}) -> V.
