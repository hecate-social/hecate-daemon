-module(briefcase_item_state).

-include("briefcase_item_status.hrl").
-include("briefcase_item_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-spec new(binary()) -> #briefcase_item_state{}.
new(ItemId) ->
    #briefcase_item_state{
        item_id = ItemId,
        size = 0,
        starred = false,
        status = 0
    }.

-spec apply_event(#briefcase_item_state{}, map()) -> #briefcase_item_state{}.
apply_event(State, Event) ->
    case gv(event_type, Event) of
        <<"briefcase_item_initiated_v1">> -> do_apply_initiated(State, Event);
        <<"briefcase_item_renamed_v1">>   -> do_apply_renamed(State, Event);
        <<"briefcase_item_moved_v1">>     -> do_apply_moved(State, Event);
        <<"briefcase_item_starred_v1">>   -> do_apply_starred(State, Event);
        <<"briefcase_item_unstarred_v1">> -> do_apply_unstarred(State, Event);
        <<"briefcase_item_archived_v1">>  -> do_apply_archived(State, Event);
        _ -> State
    end.

-spec to_map(#briefcase_item_state{}) -> map().
to_map(#briefcase_item_state{} = S) ->
    #{
        item_id    => S#briefcase_item_state.item_id,
        name       => S#briefcase_item_state.name,
        kind       => S#briefcase_item_state.kind,
        parent_id  => S#briefcase_item_state.parent_id,
        plugin     => S#briefcase_item_state.plugin,
        file_type  => S#briefcase_item_state.file_type,
        icon       => S#briefcase_item_state.icon,
        path       => S#briefcase_item_state.path,
        mime_type  => S#briefcase_item_state.mime_type,
        size       => S#briefcase_item_state.size,
        starred    => S#briefcase_item_state.starred,
        status     => S#briefcase_item_state.status,
        created_at => S#briefcase_item_state.created_at,
        updated_at => S#briefcase_item_state.updated_at
    }.

%% Internal

do_apply_initiated(State, E) ->
    Now = gv(created_at, E),
    State#briefcase_item_state{
        item_id    = gv(item_id, E),
        name       = gv(name, E),
        kind       = gv(kind, E),
        parent_id  = gv(parent_id, E),
        plugin     = gv(plugin, E),
        file_type  = gv(file_type, E),
        icon       = gv(icon, E),
        path       = gv(path, E),
        mime_type  = gv(mime_type, E),
        size       = gv(size, E, 0),
        starred    = false,
        status     = ?ITEM_INITIATED,
        created_at = Now,
        updated_at = Now
    }.

do_apply_renamed(State, E) ->
    State#briefcase_item_state{
        name       = gv(name, E),
        status     = State#briefcase_item_state.status bor ?ITEM_RENAMED,
        updated_at = gv(renamed_at, E)
    }.

do_apply_moved(State, E) ->
    State#briefcase_item_state{
        parent_id  = gv(parent_id, E),
        status     = State#briefcase_item_state.status bor ?ITEM_MOVED,
        updated_at = gv(moved_at, E)
    }.

do_apply_starred(State, E) ->
    State#briefcase_item_state{
        starred    = true,
        status     = State#briefcase_item_state.status bor ?ITEM_STARRED,
        updated_at = gv(starred_at, E)
    }.

do_apply_unstarred(State, E) ->
    State#briefcase_item_state{
        starred    = false,
        updated_at = gv(unstarred_at, E)
    }.

do_apply_archived(State, E) ->
    State#briefcase_item_state{
        status     = State#briefcase_item_state.status bor ?ITEM_ARCHIVED,
        updated_at = gv(archived_at, E)
    }.

gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.
