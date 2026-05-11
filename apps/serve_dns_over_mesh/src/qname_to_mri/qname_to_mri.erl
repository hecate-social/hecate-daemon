%%% @doc Top-level dispatcher for the qname → MRI label algebra.
%%% PLAN_DNS_OVER_MESH_PART1 §3.
%%%
%%% Structure of a mesh qname (from §3.3 examples):
%%%
%%%     <leaf>(.<inner-parts>)?(._<disc>.<parent-segment>)*.<org>.<reversed-realm>.
%%%
%%% Each type discriminator label marks a parent-child transition.
%%% A nested name like `api._s.counter._a.acme.macula.io.' has TWO
%%% discriminators: `_s' says "the label to my left is a service",
%%% `_a' says "the label to my left of `_a' is the app that
%%% service is hosted in." The terminal label before the
%%% reversed-realm is the org (no own discriminator).
%%%
%%% Algorithm (forward direction):
%%%   1. Normalise (lowercase, strip trailing dot, split on `.').
%%%   2. Detect reverse-arpa zone → delegate to qname_reverse_v6.
%%%   3. Strip the configured mesh_suffix labels from the right.
%%%   4. Walk the remainder left-to-right collecting (leaf, then
%%%      chain of (disc, parent-segment) pairs, then terminal org).
%%%   5. The leftmost type discriminator names the MRI type; the
%%%      collected segments form the path (org first, leaf last).
%%%
%%% Proc/topic are special-cased: any labels left of their `_p' /
%%% `_t' discriminator that aren't themselves part of a further
%%% nested chain get flattened with `.' into a single MRI segment
%%% (§3.4.2).
%%%
%%% Station is special-cased: a single label before `_st' carrying
%%% a z32 pubkey, no realm field in the MRI (delegated to
%%% qname_station).
%%%
%%% Realm apex + org are dispatched to their own modules
%%% (handled when no discriminator is found, §3.3 examples 1-2).
%%%
%%% Also exposes `format/1' for the reverse direction (MRI → qname),
%%% used by RR synthesis (PTR target, NS / SOA MNAME) and the
%%% round-trip property test.
%%% @end
-module(qname_to_mri).

-export([resolve/1, format/1]).

%% Type-discriminator label → MRI type atom. PLAN PART1 §3.1.
-define(DISC_TO_TYPE, #{
    <<"_u">>   => user,
    <<"_a">>   => app,
    <<"_s">>   => service,
    <<"_d">>   => device,
    <<"_cl">>  => cluster,
    <<"_lo">>  => location,
    <<"_z">>   => zone,
    <<"_n">>   => network,
    <<"_m">>   => model,
    <<"_ds">>  => dataset,
    <<"_cfg">> => config,
    <<"_t">>   => topic,
    <<"_p">>   => proc,
    <<"_ar">>  => artifact,
    <<"_lic">> => license,
    <<"_crt">> => cert,
    <<"_k">>   => key,
    <<"_cls">> => class,
    <<"_tx">>  => taxonomy,
    <<"_st">>  => station
}).

-define(TYPE_TO_DISC, #{
    user      => <<"_u">>,
    app       => <<"_a">>,
    service   => <<"_s">>,
    device    => <<"_d">>,
    cluster   => <<"_cl">>,
    location  => <<"_lo">>,
    zone      => <<"_z">>,
    network   => <<"_n">>,
    model     => <<"_m">>,
    dataset   => <<"_ds">>,
    config    => <<"_cfg">>,
    topic     => <<"_t">>,
    proc      => <<"_p">>,
    artifact  => <<"_ar">>,
    license   => <<"_lic">>,
    cert      => <<"_crt">>,
    key       => <<"_k">>,
    class     => <<"_cls">>,
    taxonomy  => <<"_tx">>,
    station   => <<"_st">>
}).

%% Total qname octet cap (RFC 1035 §2.3.4). Includes length octets.
-define(MAX_QNAME_OCTETS, 255).
-define(MAX_LABEL_OCTETS, 63).

-define(DEFAULT_MESH_SUFFIX, <<"macula.io.">>).

%%====================================================================
%% Forward: qname → MRI
%%====================================================================

-spec resolve(binary()) -> {ok, binary()} | {error, atom()}.
resolve(QName) when is_binary(QName) ->
    case normalise(QName) of
        {error, _} = Err -> Err;
        Norm ->
            case is_reverse_arpa(Norm) of
                true  -> qname_reverse_v6:resolve(Norm);
                false -> resolve_forward(Norm)
            end
    end;
resolve(_) ->
    {error, malformed_qname}.

normalise(<<>>) ->
    {error, malformed_qname};
normalise(QName) when byte_size(QName) > ?MAX_QNAME_OCTETS ->
    {error, name_too_long};
normalise(QName) ->
    Lower = string:lowercase(QName),
    case binary:last(Lower) of
        $. -> binary:part(Lower, 0, byte_size(Lower) - 1);
        _  -> Lower
    end.

is_reverse_arpa(QName) ->
    suffix_match(QName, <<"ip6.arpa">>) orelse
        suffix_match(QName, <<"in-addr.arpa">>).

suffix_match(QName, Suffix) ->
    QSize = byte_size(QName),
    SSize = byte_size(Suffix),
    QSize >= SSize andalso
        binary:part(QName, QSize - SSize, SSize) =:= Suffix.

resolve_forward(QName) ->
    Labels = binary:split(QName, <<".">>, [global]),
    case validate_labels(Labels) of
        ok ->
            MeshSuffixLabels = mesh_suffix_labels(),
            case strip_suffix(Labels, MeshSuffixLabels) of
                {ok, Remainder} -> classify_remainder(Remainder, MeshSuffixLabels);
                {error, _} = E  -> E
            end;
        {error, _} = E ->
            E
    end.

mesh_suffix_labels() ->
    Suffix = application:get_env(serve_dns_over_mesh, mesh_suffix,
                                 ?DEFAULT_MESH_SUFFIX),
    SuffixBin = case is_list(Suffix) of
                    true  -> list_to_binary(Suffix);
                    false -> Suffix
                end,
    Trimmed = case binary:last(SuffixBin) of
                  $. -> binary:part(SuffixBin, 0, byte_size(SuffixBin) - 1);
                  _  -> SuffixBin
              end,
    binary:split(Trimmed, <<".">>, [global]).

strip_suffix(Labels, SuffixLabels) ->
    case lists:suffix(SuffixLabels, Labels) of
        true  -> {ok, lists:sublist(Labels, length(Labels) - length(SuffixLabels))};
        false -> {error, not_in_mesh_suffix}
    end.

validate_labels([]) ->
    {error, malformed_qname};
validate_labels(Labels) ->
    case lists:any(fun(L) -> byte_size(L) =:= 0 orelse byte_size(L) > ?MAX_LABEL_OCTETS end,
                   Labels) of
        true  -> {error, malformed_qname};
        false -> ok
    end.

%% Classify the labels that remain after the mesh_suffix has been stripped.
%%   []                    → realm apex (qname == mesh_suffix)
%%   [Org]                 → org MRI (single label, no discriminator)
%%   _ with discriminator  → typed MRI; walk for path + type
classify_remainder([], MeshSuffix) ->
    Realm = labels_to_realm(MeshSuffix),
    mri_new(realm, Realm, []);
classify_remainder([Org], MeshSuffix) ->
    qname_org:resolve(Org, MeshSuffix);
classify_remainder(Remainder, MeshSuffix) ->
    %% Find the LEFTMOST discriminator. That names the MRI type.
    %% Everything left of it is the leaf segment(s); everything
    %% right of it is the parent chain culminating in the org.
    case scan_for_first_disc(Remainder, 0) of
        not_found ->
            {error, malformed_qname};
        {Type, Idx} ->
            {LeafPart, [_Disc | RightOfFirst]} = lists:split(Idx, Remainder),
            dispatch_type(Type, LeafPart, RightOfFirst, MeshSuffix)
    end.

scan_for_first_disc([], _) ->
    not_found;
scan_for_first_disc([L | Rest], I) ->
    case maps:find(L, ?DISC_TO_TYPE) of
        {ok, Type} -> {Type, I};
        error      -> scan_for_first_disc(Rest, I + 1)
    end.

%% Dispatch per leaf type. The per-type module gets:
%%   LeafPart    = DNS labels left of the leaf's discriminator,
%%                 in leftmost-first order
%%   ParentChain = labels right of the leaf's discriminator, in
%%                 leftmost-first order. May contain further
%%                 (disc, segment) pairs for nested types ending
%%                 with the org as terminal label.
%%   MeshSuffix  = the stripped suffix labels in DNS order (e.g.,
%%                 [<<"macula">>, <<"io">>]). Used to build the
%%                 MRI realm.
dispatch_type(station, [Z32Label], [], _MeshSuffix) ->
    %% Station qname = <z32>._st.<mesh_suffix>. No realm in MRI;
    %% the pubkey IS the identifier.
    qname_station:resolve([Z32Label], []);
dispatch_type(proc, LeafPart, ParentChain, MeshSuffix) ->
    %% Dotted-segment flattening (§3.4.2). LeafPart in DNS order
    %% (leftmost first); reverse to get MRI order then join with `.'.
    %% ParentChain must collapse to a single org.
    %%
    %% NOTE: macula_mri:new/3 (4.2.x) rejects `.' inside segments,
    %% but PART1 §3.4.2 explicitly allows it for proc/topic ("the
    %% org segment is the first chunk; everything after is a single
    %% dotted-string"). Construct the MRI literal directly to match
    %% the §3.3 spec example. SDK 4.3.0 candidate: relax validator
    %% for proc/topic segments.
    case org_from_parent_chain(ParentChain) of
        {ok, Org} ->
            Realm = labels_to_realm(MeshSuffix),
            DottedSeg = iolist_to_binary(
                          lists:join(<<".">>, lists:reverse(LeafPart))),
            {ok, <<"mri:proc:", Realm/binary, "/", Org/binary, "/", DottedSeg/binary>>};
        {error, _} = E ->
            E
    end;
dispatch_type(topic, LeafPart, ParentChain, MeshSuffix) ->
    case org_from_parent_chain(ParentChain) of
        {ok, Org} ->
            Realm = labels_to_realm(MeshSuffix),
            DottedSeg = iolist_to_binary(
                          lists:join(<<".">>, lists:reverse(LeafPart))),
            {ok, <<"mri:topic:", Realm/binary, "/", Org/binary, "/", DottedSeg/binary>>};
        {error, _} = E ->
            E
    end;
dispatch_type(Type, LeafPart, ParentChain, MeshSuffix) ->
    %% Simple / nested non-special types. LeafPart is a single
    %% label (the leaf segment). ParentChain is the chain leading
    %% to the org. Path in MRI order = [Org | reverse(ParentSegs)]
    %% ++ [Leaf].
    case LeafPart of
        [Leaf] ->
            case walk_parent_chain(ParentChain) of
                {ok, ParentSegsInDnsOrder, Org} ->
                    Realm = labels_to_realm(MeshSuffix),
                    %% MRI path order: [Org, deepest-ancestor, ...,
                    %% immediate-parent, Leaf]. ParentSegsInDnsOrder
                    %% has immediate parent FIRST in DNS order (which
                    %% is closer-to-leaf). Reverse → MRI parent order.
                    Path = [Org | lists:reverse(ParentSegsInDnsOrder)] ++ [Leaf],
                    qname_simple:from_components(Type, Realm, Path);
                {error, _} = E ->
                    E
            end;
        _ ->
            {error, malformed_qname}
    end.

%% Walk the parent chain (labels right of the leaf's disc, in DNS
%% order). Expected shape: zero-or-more (segment, disc) pairs
%% followed by a terminal segment (the org).
%%
%% Returns {ok, [DnsParentSegment, ...], OrgLabel} where the parent
%% segments appear closest-to-leaf first (i.e., in DNS order).
walk_parent_chain(Chain) ->
    walk_parent_chain(Chain, []).

walk_parent_chain([Org], Acc) ->
    {ok, lists:reverse(Acc), Org};
walk_parent_chain([Segment, Disc | Rest], Acc) ->
    case maps:is_key(Disc, ?DISC_TO_TYPE) of
        true  -> walk_parent_chain(Rest, [Segment | Acc]);
        false -> {error, malformed_qname}
    end;
walk_parent_chain(_, _) ->
    {error, malformed_qname}.

%% Proc/topic only allow the org as a direct parent (no nested
%% disc chain). The parent chain MUST be exactly one label (the org).
org_from_parent_chain([Org]) -> {ok, Org};
org_from_parent_chain(_)     -> {error, malformed_qname}.

%%====================================================================
%% Reverse: MRI → qname
%%====================================================================

-spec format(binary() | map()) -> {ok, binary()} | {error, atom()}.
format(<<"mri:station:", Pubkey/binary>>) ->
    %% Bypass macula_mri:parse because the SDK doesn't recognise
    %% the station type yet (lands in 4.3.0). Treat as a leaf form.
    format_station(Pubkey);
format(<<"mri:", _/binary>> = Mri) ->
    case macula_mri:parse(Mri) of
        {ok, Map}      -> format(Map);
        {error, _} = E -> E
    end;
format(#{type := Type, realm := Realm, path := Path}) ->
    format_for_type(Type, Realm, Path);
format(_) ->
    {error, invalid_input}.

format_for_type(realm, Realm, []) ->
    build_qname_simple([], <<>>, [], realm_to_dns_labels(Realm));
format_for_type(org, Realm, [Org]) ->
    build_qname_simple([Org], <<>>, [], realm_to_dns_labels(Realm));
format_for_type(proc, Realm, [Org, Dotted]) ->
    %% MRI path = [Org, "api.users.get"]. DNS form: split dotted
    %% on `.', reverse, prepend disc + org + reversed realm.
    Parts = binary:split(Dotted, <<".">>, [global]),
    DnsLeafPart = lists:reverse(Parts),
    build_qname_with_chain(DnsLeafPart, disc(proc), [], Org, realm_to_dns_labels(Realm));
format_for_type(topic, Realm, [Org, Dotted]) ->
    Parts = binary:split(Dotted, <<".">>, [global]),
    DnsLeafPart = lists:reverse(Parts),
    build_qname_with_chain(DnsLeafPart, disc(topic), [], Org, realm_to_dns_labels(Realm));
format_for_type(Type, Realm, [Org | Rest]) when length(Rest) >= 1 ->
    %% Nested case: path = [Org, p1, p2, ..., pN, Leaf]
    %% DNS form: <Leaf>.<disc(Type)>.<pN>.<disc(parent-type)>.
    %%           <pN-1>.<disc(grandparent)>...<Org>.<realm-rev>.
    %% We need parent types — derive from the path length convention:
    %% for `service' under `app' under `org', path = [Org, App, Service].
    %% Each intermediate parent gets its own disc based on Type's hierarchy.
    case nested_parent_discs(Type, length(Rest) - 1) of
        {ok, ParentDiscs} ->
            [Leaf | RestRev] = lists:reverse(Rest),
            ParentSegsInMriOrder = lists:reverse(RestRev),
            %% Build DNS form: leaf, leaf-disc, then alternating
            %% (parent-segment, parent-disc) pairs in REVERSE MRI
            %% order, then org, then reversed realm.
            build_qname_with_chain([Leaf], disc(Type),
                                   pair_with_discs(
                                     lists:reverse(ParentSegsInMriOrder),
                                     ParentDiscs),
                                   Org, realm_to_dns_labels(Realm));
        {error, _} = E ->
            E
    end;
format_for_type(Type, _Realm, _Path) ->
    {error, {unknown_or_unsupported_type, Type}}.

%% For nested types, return the discriminator labels for each
%% PARENT level (in DNS order: immediate parent first, deepest last).
%% E.g., for type=service with one intermediate parent (an app):
%% → {ok, [<<"_a">>]}.
%% For type=user with zero intermediate parents (path = [Org, User]):
%% → {ok, []}.
nested_parent_discs(Type, 0) ->
    case maps:is_key(Type, ?TYPE_TO_DISC) of
        true  -> {ok, []};
        false -> {error, {unknown_type, Type}}
    end;
nested_parent_discs(service, 1) ->
    {ok, [disc(app)]};
nested_parent_discs(_Type, N) when N > 0 ->
    %% Other nested cases not yet specified in PART1 §3.3 worked
    %% examples; surface a typed error rather than guessing.
    {error, {nested_parent_chain_not_specified_for_path_depth, N}}.

%% Pair parent segments with their discriminators (DNS order).
pair_with_discs([], []) -> [];
pair_with_discs([Seg | Segs], [Disc | Discs]) ->
    [Seg, Disc | pair_with_discs(Segs, Discs)].

%% Build qname for simple cases (no parent chain after the leaf-disc).
build_qname_simple(LeafLabels, Disc, _ParentChain, RealmDnsLabels) ->
    AllLabels =
        case Disc of
            <<>> -> LeafLabels ++ RealmDnsLabels;
            _    -> LeafLabels ++ [Disc] ++ RealmDnsLabels
        end,
    finalise_qname(AllLabels).

%% Build qname with a parent chain (nested types like service).
%% Structure: leaf-labels, leaf-disc, parent-chain (alternating
%% segment-disc pairs), org, reversed-realm.
build_qname_with_chain(LeafLabels, LeafDisc, ParentChain, Org, RealmDnsLabels) ->
    AllLabels = LeafLabels ++ [LeafDisc] ++ ParentChain ++ [Org] ++ RealmDnsLabels,
    finalise_qname(AllLabels).

finalise_qname(AllLabels) ->
    case validate_labels(AllLabels) of
        ok ->
            QName = iolist_to_binary(lists:join($., AllLabels)),
            FQDN = <<QName/binary, ".">>,
            case byte_size(FQDN) > ?MAX_QNAME_OCTETS of
                true  -> {error, name_too_long};
                false -> {ok, FQDN}
            end;
        {error, _} = E ->
            E
    end.

format_station(Pubkey) ->
    case qname_station:format_pubkey(Pubkey) of
        {ok, Z32} ->
            build_qname_simple([Z32], disc(station), [], [<<"macula">>, <<"io">>]);
        {error, _} = E ->
            E
    end.

%% Helpers shared by forward + reverse directions.

labels_to_realm(DnsLabels) ->
    iolist_to_binary(lists:join(<<".">>, lists:reverse(DnsLabels))).

realm_to_dns_labels(Realm) ->
    %% MRI realm "io.macula" → DNS labels ["macula", "io"]
    %% (reversed, leftmost-first for DNS).
    lists:reverse(binary:split(Realm, <<".">>, [global])).

disc(Type) -> maps:get(Type, ?TYPE_TO_DISC).

%%====================================================================
%% MRI construction. macula_mri:new/3 validates + formats.
%% Station MRIs are constructed by qname_station directly because
%% macula_mri 4.2.x doesn't recognise the station type.
%%====================================================================

mri_new(Type, Realm, Path) ->
    case macula_mri:new(Type, Realm, Path) of
        {ok, Mri}      -> {ok, Mri};
        {error, _} = E -> E
    end.
