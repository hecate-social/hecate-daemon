%%% @doc unpair_node_v1 command
-module(unpair_node_v1).

-export([new/2, to_map/1, from_map/1]).

-record(unpair_node_v1, {
    reason      :: binary(),
    unpaired_at :: integer()
}).

-opaque unpair_node_v1() :: #unpair_node_v1{}.
-export_type([unpair_node_v1/0]).

-spec new(binary(), integer()) -> unpair_node_v1().
new(Reason, UnpairedAt) ->
    #unpair_node_v1{reason = Reason, unpaired_at = UnpairedAt}.

-spec to_map(unpair_node_v1()) -> map().
to_map(#unpair_node_v1{reason = Reason, unpaired_at = UnpairedAt}) ->
    #{reason => Reason, unpaired_at => UnpairedAt}.

-spec from_map(map()) -> {ok, unpair_node_v1()} | {error, term()}.
from_map(#{reason := Reason, unpaired_at := UnpairedAt}) ->
    {ok, #unpair_node_v1{reason = Reason, unpaired_at = UnpairedAt}};
from_map(_) ->
    {error, invalid_unpair_node_command}.
