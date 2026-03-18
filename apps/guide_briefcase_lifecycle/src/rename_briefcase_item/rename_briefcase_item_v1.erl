-module(rename_briefcase_item_v1).
-behaviour(evoq_command).
-export([new/1, to_map/1, from_map/1, validate/1, command_type/0]).
-record(rename_briefcase_item_v1, {item_id, name}).
command_type() -> rename_briefcase_item.
new(P) -> {ok, #rename_briefcase_item_v1{item_id = gv(item_id, P), name = gv(name, P)}}.
validate(#rename_briefcase_item_v1{item_id = I}) when not is_binary(I); byte_size(I) =:= 0 -> {error, item_id_required};
validate(#rename_briefcase_item_v1{name = N}) when not is_binary(N); byte_size(N) =:= 0 -> {error, name_required};
validate(C) -> {ok, C}.
to_map(#rename_briefcase_item_v1{item_id = I, name = N}) ->
    #{command_type => <<"rename_briefcase_item">>, item_id => I, name => N}.
from_map(M) -> {ok, #rename_briefcase_item_v1{item_id = gv(item_id, M), name = gv(name, M)}}.
gv(K, M) -> case maps:find(K, M) of {ok, V} -> V; error -> maps:get(atom_to_binary(K), M, undefined) end.
