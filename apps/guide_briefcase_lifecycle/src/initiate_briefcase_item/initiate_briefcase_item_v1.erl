-module(initiate_briefcase_item_v1).
-behaviour(evoq_command).
-export([new/1, to_map/1, from_map/1, validate/1, command_type/0]).

-record(initiate_briefcase_item_v1, {
    item_id, name, kind, parent_id, plugin, file_type, icon, path, mime_type, size
}).

command_type() -> initiate_briefcase_item.

new(Params) -> {ok, from_params(Params)}.

validate(#initiate_briefcase_item_v1{item_id = Id}) when not is_binary(Id); byte_size(Id) =:= 0 ->
    {error, item_id_required};
validate(#initiate_briefcase_item_v1{name = N}) when not is_binary(N); byte_size(N) =:= 0 ->
    {error, name_required};
validate(#initiate_briefcase_item_v1{kind = K}) when K =/= <<"folder">>, K =/= <<"blob">>, K =/= <<"symlink">> ->
    {error, invalid_kind};
validate(Cmd) -> {ok, Cmd}.

to_map(#initiate_briefcase_item_v1{} = C) ->
    mp(#{
        command_type => <<"initiate_briefcase_item">>,
        item_id   => C#initiate_briefcase_item_v1.item_id,
        name      => C#initiate_briefcase_item_v1.name,
        kind      => C#initiate_briefcase_item_v1.kind
    }, [
        {parent_id, C#initiate_briefcase_item_v1.parent_id},
        {plugin, C#initiate_briefcase_item_v1.plugin},
        {file_type, C#initiate_briefcase_item_v1.file_type},
        {icon, C#initiate_briefcase_item_v1.icon},
        {path, C#initiate_briefcase_item_v1.path},
        {mime_type, C#initiate_briefcase_item_v1.mime_type},
        {size, C#initiate_briefcase_item_v1.size}
    ]).

from_map(Map) -> {ok, from_params(Map)}.

from_params(M) ->
    #initiate_briefcase_item_v1{
        item_id   = gv(item_id, M),
        name      = gv(name, M),
        kind      = gv(kind, M),
        parent_id = gv(parent_id, M),
        plugin    = gv(plugin, M),
        file_type = gv(file_type, M),
        icon      = gv(icon, M),
        path      = gv(path, M),
        mime_type = gv(mime_type, M),
        size      = gv(size, M, 0)
    }.

gv(K, M) -> gv(K, M, undefined).
gv(K, M, D) when is_atom(K) ->
    case maps:find(K, M) of {ok, V} -> V; error -> maps:get(atom_to_binary(K), M, D) end.

mp(Base, []) -> Base;
mp(Base, [{_K, undefined} | T]) -> mp(Base, T);
mp(Base, [{K, V} | T]) -> mp(Base#{K => V}, T).
