%%% @doc Per-type rule for MRI type `topic'. PLAN PART1 §3.4.2: same
%%% dot-flattening rule as proc — first segment is org, rest is a
%%% single dotted chunk.
%%%
%%% Example: `mri:topic:io.macula/acme/orders.placed' ↔
%%% `placed.orders._t.acme.macula.io.'
%%% @end
-module(qname_topic).

-export([resolve/2]).

-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve([], _Right) -> {error, malformed_qname};
resolve(_Left, []) -> {error, malformed_qname};
resolve(Left, Right) ->
    Realm = iolist_to_binary(lists:join(<<".">>, lists:reverse(Right))),
    case lists:reverse(Left) of
        [Org] ->
            macula_mri:new(topic, Realm, [Org]);
        [Org | DottedParts] ->
            DottedSeg = iolist_to_binary(lists:join(<<".">>, DottedParts)),
            macula_mri:new(topic, Realm, [Org, DottedSeg])
    end.
