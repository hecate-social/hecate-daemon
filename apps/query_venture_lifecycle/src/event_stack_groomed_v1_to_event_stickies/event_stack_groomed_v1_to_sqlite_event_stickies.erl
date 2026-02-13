%%% @doc Projection: event_stack_groomed_v1 -> event_stickies table
%%%
%%% Grooming a stack updates the canonical sticky's weight and
%%% deletes all absorbed stickies.
-module(event_stack_groomed_v1_to_sqlite_event_stickies).
-export([project/1]).

project(Event) ->
    CanonicalId = get(canonical_sticky_id, Event),
    Weight = get(weight, Event, 1),
    AbsorbedIds = get(absorbed_sticky_ids, Event, []),
    logger:info("[PROJECTION] ~s: grooming stack, canonical=~s weight=~p absorbed=~p",
                [?MODULE, CanonicalId, Weight, length(AbsorbedIds)]),
    %% Update canonical sticky
    Sql1 = "UPDATE event_stickies SET weight = ?1, stack_id = NULL WHERE sticky_id = ?2",
    ok = query_venture_lifecycle_store:execute(Sql1, [Weight, CanonicalId]),
    %% Delete absorbed stickies
    lists:foreach(fun(Id) ->
        Sql2 = "DELETE FROM event_stickies WHERE sticky_id = ?1",
        query_venture_lifecycle_store:execute(Sql2, [Id])
    end, AbsorbedIds),
    ok.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

get(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.
