-module(briefcase_item_lifecycle_to_items).
-behaviour(evoq_projection).

-include_lib("guide_briefcase_lifecycle/include/briefcase_item_status.hrl").

-export([interested_in/0, init/1, project/4]).

interested_in() -> [
    <<"briefcase_item_initiated_v1">>,
    <<"briefcase_item_renamed_v1">>,
    <<"briefcase_item_moved_v1">>,
    <<"briefcase_item_starred_v1">>,
    <<"briefcase_item_unstarred_v1">>,
    <<"briefcase_item_archived_v1">>
].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => briefcase_items}),
    {ok, #{}, RM}.

project(Event, _Meta, State, RM) ->
    Data = maps:get(data, Event),
    Type = maps:get(event_type, Event, gf(event_type, Data)),
    case Type of
        <<"briefcase_item_initiated_v1">> -> project_initiated(Data, State, RM);
        <<"briefcase_item_renamed_v1">>   -> project_update(Data, State, RM, fun do_rename/2);
        <<"briefcase_item_moved_v1">>     -> project_update(Data, State, RM, fun do_move/2);
        <<"briefcase_item_starred_v1">>   -> project_update(Data, State, RM, fun do_star/2);
        <<"briefcase_item_unstarred_v1">> -> project_update(Data, State, RM, fun do_unstar/2);
        <<"briefcase_item_archived_v1">>  -> project_archived(Data, State, RM);
        _ -> {ok, State, RM}
    end.

project_initiated(Data, State, RM) ->
    Id = gf(item_id, Data),
    Now = gf(created_at, Data),
    Item = #{
        item_id    => Id,
        name       => gf(name, Data),
        kind       => gf(kind, Data),
        parent_id  => gf(parent_id, Data),
        plugin     => gf(plugin, Data),
        file_type  => gf(file_type, Data),
        icon       => gf(icon, Data),
        path       => gf(path, Data),
        mime_type  => gf(mime_type, Data),
        size       => gf(size, Data, 0),
        starred    => false,
        status     => ?ITEM_INITIATED,
        created_at => Now,
        updated_at => Now
    },
    project_briefcase_store:put_item(Id, Item),
    {ok, State, RM}.

project_update(Data, State, RM, UpdateFn) ->
    Id = gf(item_id, Data),
    case project_briefcase_store:get_item(Id) of
        {ok, Existing} ->
            Updated = UpdateFn(Existing, Data),
            project_briefcase_store:put_item(Id, Updated),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end.

project_archived(Data, State, RM) ->
    Id = gf(item_id, Data),
    project_briefcase_store:delete_item(Id),
    {ok, State, RM}.

do_rename(Item, Data) ->
    Item#{
        name       => gf(name, Data),
        status     => maps:get(status, Item) bor ?ITEM_RENAMED,
        updated_at => gf(renamed_at, Data)
    }.

do_move(Item, Data) ->
    Item#{
        parent_id  => gf(parent_id, Data),
        status     => maps:get(status, Item) bor ?ITEM_MOVED,
        updated_at => gf(moved_at, Data)
    }.

do_star(Item, Data) ->
    Item#{
        starred    => true,
        status     => maps:get(status, Item) bor ?ITEM_STARRED,
        updated_at => gf(starred_at, Data)
    }.

do_unstar(Item, Data) ->
    Item#{
        starred    => false,
        updated_at => gf(unstarred_at, Data)
    }.

gf(Key, Map) -> gf(Key, Map, undefined).
gf(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.
