%%% @doc node_unpaired_v1 event
-module(node_unpaired_v1).

-export([new/2, to_map/1, from_map/1]).

-record(node_unpaired_v1, {
    reason      :: binary(),
    unpaired_at :: integer()
}).

-opaque node_unpaired_v1() :: #node_unpaired_v1{}.
-export_type([node_unpaired_v1/0]).

-spec new(binary(), integer()) -> node_unpaired_v1().
new(Reason, UnpairedAt) ->
    #node_unpaired_v1{reason = Reason, unpaired_at = UnpairedAt}.

-spec to_map(node_unpaired_v1()) -> map().
to_map(#node_unpaired_v1{reason = Reason, unpaired_at = UnpairedAt}) ->
    #{
        event_type => <<"node_unpaired_v1">>,
        reason => Reason,
        unpaired_at => UnpairedAt
    }.

-spec from_map(map()) -> {ok, node_unpaired_v1()} | {error, term()}.
from_map(#{reason := Reason, unpaired_at := UnpairedAt}) ->
    {ok, #node_unpaired_v1{reason = Reason, unpaired_at = UnpairedAt}};
from_map(_) ->
    {error, invalid_node_unpaired_event}.
