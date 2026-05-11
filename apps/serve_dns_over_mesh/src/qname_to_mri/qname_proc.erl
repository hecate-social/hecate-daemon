%%% @doc Per-type rule for MRI type `proc'. PLAN PART1 §3.4.2:
%%% the org segment is the first slash-separated chunk; everything
%%% after is a single dotted-string flattened into multiple DNS
%%% labels (split-on-dot).
%%%
%%% Example: qname `get.users.api._p.acme.macula.io.' →
%%%   Left  = `[<<"get">>, <<"users">>, <<"api">>, <<"acme">>]'  (DNS order)
%%%   Right = `[<<"macula">>, <<"io">>]'                          (DNS order)
%%% Reverse Left → MRI path-as-labels: `[<<"acme">>, <<"api">>, <<"users">>, <<"get">>]'
%%% First label is org segment; remaining join with `.' into single
%%% MRI segment: org=`<<"acme">>', dotted=`<<"api.users.get">>'.
%%% Result: `mri:proc:io.macula/acme/api.users.get'.
%%% @end
-module(qname_proc).

-export([resolve/2]).

-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve([], _Right) -> {error, malformed_qname};
resolve(_Left, []) -> {error, malformed_qname};
resolve(Left, Right) ->
    Realm = iolist_to_binary(lists:join(<<".">>, lists:reverse(Right))),
    case lists:reverse(Left) of
        [Org] ->
            macula_mri:new(proc, Realm, [Org]);
        [Org | DottedParts] ->
            DottedSeg = iolist_to_binary(lists:join(<<".">>, DottedParts)),
            macula_mri:new(proc, Realm, [Org, DottedSeg])
    end.
