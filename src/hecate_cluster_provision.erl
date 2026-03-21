%%%-------------------------------------------------------------------
%%% @doc Headless cluster node self-provisioning.
%%%
%%% On boot, checks if this node has realm membership (via replicated
%%% ReckonDB events) but no local mesh credentials. If so, uses the
%%% replicated refresh token to call the realm server's cluster
%%% provisioning endpoint and obtain a per-node certificate.
%%%
%%% This enables headless nodes (beam00-03) to automatically join
%%% the mesh without human interaction — they inherit realm membership
%%% from an attended node (laptop) that did the original OAuth.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_cluster_provision).

-export([maybe_provision/0]).

-define(PROVISION_PATH, "/api/v1/cluster/provision").

%% @doc Check if this node needs provisioning and do it if so.
%% Called during boot after projections are replayed.
%% Returns ok (provisioned or not needed) or {error, Reason}.
-spec maybe_provision() -> ok | {error, term()}.
maybe_provision() ->
    case needs_provisioning() of
        {true, MembershipId} ->
            logger:info("[cluster-provision] Node needs provisioning for membership ~s", [MembershipId]),
            do_provision(MembershipId);
        false ->
            ok
    end.

%%%===================================================================
%%% Internal
%%%===================================================================

%% @private Check if we have confirmed realm membership but no local cert.
needs_provisioning() ->
    case has_local_cert() of
        true ->
            false;
        false ->
            case get_confirmed_membership() of
                {ok, MembershipId} -> {true, MembershipId};
                not_found -> false
            end
    end.

%% @private Check if we already have a local cert file.
has_local_cert() ->
    Path = cert_path(),
    filelib:is_regular(Path).

%% @private Get the first confirmed membership from replicated ETS.
get_confirmed_membership() ->
    try project_realm_memberships_store:list_confirmed() of
        {ok, [#{membership_id := MId} | _]} -> {ok, MId};
        _ -> not_found
    catch
        _:_ -> not_found
    end.

%% @private Provision this node with the realm server.
do_provision(MembershipId) ->
    case project_realm_memberships_store:get_credentials(MembershipId) of
        {ok, Creds} ->
            RefreshToken = maps:get(refresh_token, Creds, undefined),
            RealmUrl = get_realm_url(MembershipId),
            provision_with_token(RefreshToken, RealmUrl);
        {error, Reason} ->
            logger:warning("[cluster-provision] No credentials for ~s: ~p", [MembershipId, Reason]),
            {error, no_credentials}
    end.

%% @private Call the realm server provisioning endpoint.
provision_with_token(undefined, _RealmUrl) ->
    {error, no_refresh_token};
provision_with_token(RefreshToken, RealmUrl) ->
    {ok, PubKey} = hecate_identity:get_public_key(),
    PubKeyB64 = base64:encode(PubKey),
    NodeName = node_name(),

    Url = <<RealmUrl/binary, ?PROVISION_PATH>>,
    Body = json:encode(#{
        public_key => PubKeyB64,
        node_name => NodeName,
        node_info => node_info()
    }),
    Headers = [
        {<<"content-type">>, <<"application/json">>},
        {<<"authorization">>, <<"Bearer ", RefreshToken/binary>>}
    ],

    case hackney:request(post, Url, Headers, Body, [with_body]) of
        {ok, 201, _RespHeaders, RespBody} ->
            Data = json:decode(RespBody),
            CertPem = maps:get(<<"cert_pem">>, Data),
            OrgIdentity = maps:get(<<"org_identity">>, Data),
            save_local_cert(CertPem),
            logger:info("[cluster-provision] Provisioned successfully: ~s", [OrgIdentity]),
            ok;
        {ok, Status, _RespHeaders, RespBody} ->
            logger:error("[cluster-provision] Provisioning failed: ~p ~s", [Status, RespBody]),
            {error, {http_error, Status}};
        {error, Reason} ->
            logger:error("[cluster-provision] Provisioning request failed: ~p", [Reason]),
            {error, Reason}
    end.

%% @private Get realm URL from membership projection or default.
get_realm_url(MembershipId) ->
    case project_realm_memberships_store:get(MembershipId) of
        {ok, #{realm_url := Url}} when is_binary(Url) -> Url;
        _ -> <<"https://macula.io">>
    end.

%% @private Short node name for the provisioning request.
node_name() ->
    FullNode = atom_to_binary(node(), utf8),
    case binary:split(FullNode, <<"@">>) of
        [Name, _Host] -> Name;
        _ -> shared_host:hostname()
    end.

%% @private Node info for the provisioning request.
node_info() ->
    {ok, Vsn} = application:get_key(hecate, vsn),
    #{
        hostname => shared_host:hostname(),
        os => os_type_to_binary(),
        version => list_to_binary(Vsn)
    }.

os_type_to_binary() ->
    {OsFamily, OsName} = os:type(),
    iolist_to_binary([atom_to_list(OsFamily), "/", atom_to_list(OsName)]).

%% @private Save cert to local file.
save_local_cert(CertPem) ->
    Path = cert_path(),
    ok = filelib:ensure_dir(Path),
    ok = file:write_file(Path, CertPem).

%% @private Path to local cert file.
cert_path() ->
    filename:join(shared_paths:base_dir(), "node.cert.pem").
