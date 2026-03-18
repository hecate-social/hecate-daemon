-module(star_briefcase_item_v1).
-behaviour(evoq_command).
-export([new/1, to_map/1, from_map/1, validate/1, command_type/0]).
-record(star_briefcase_item_v1, {item_id}).
command_type() -> star_briefcase_item.
new(P) -> {ok, #star_briefcase_item_v1{item_id = gv(item_id, P)}}.
validate(#star_briefcase_item_v1{item_id = I}) when not is_binary(I); byte_size(I) =:= 0 -> {error, item_id_required};
validate(C) -> {ok, C}.
to_map(#star_briefcase_item_v1{item_id = I}) -> #{command_type => <<"star_briefcase_item">>, item_id => I}.
from_map(M) -> {ok, #star_briefcase_item_v1{item_id = gv(item_id, M)}}.
gv(K, M) -> case maps:find(K, M) of {ok, V} -> V; error -> maps:get(atom_to_binary(K), M, undefined) end.
