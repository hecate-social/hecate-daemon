%%% @doc Per-type rule for MRI type `org'. Special case: org has no
%%% type discriminator; the leftmost label of the suffix is the org
%%% itself. The dispatcher's classify_no_disc passes the labels
%%% pre-split into `Org' (single binary) and the realm-DNS-labels.
%%%
%%% Example: org=`<<"acme">>', realm-DNS=`[<<"macula">>, <<"io">>]'
%%% → `mri:org:io.macula/acme'.
%%% @end
-module(qname_org).

-export([resolve/2]).

-spec resolve(Org :: binary(), RealmDnsLabels :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve(Org, RealmDnsLabels) when is_binary(Org), length(RealmDnsLabels) >= 2 ->
    Realm = iolist_to_binary(lists:join(<<".">>, lists:reverse(RealmDnsLabels))),
    case macula_mri:new(org, Realm, [Org]) of
        {ok, Mri}      -> {ok, Mri};
        {error, _} = E -> E
    end;
resolve(_, _) ->
    {error, malformed_qname}.
