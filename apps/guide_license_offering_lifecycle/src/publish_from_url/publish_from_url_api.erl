%%% @doc API handler: POST /api/appstore/publish-from-url
%%%
%%% Fetches a manifest.json from a URL (e.g. GitHub repo),
%%% computes trust verification (SHA-256 checksum, Ed25519 signature,
%%% OCI image existence), then dispatches initiate_offering_v1 to
%%% create a catalog entry and auto-publishes it.
%%% @end
-module(publish_from_url_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/publish-from-url", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            hecate_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        AuthorId ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} ->
                    do_publish_from_url(Params, AuthorId, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_publish_from_url(Params, AuthorId, Req) ->
    Url = hecate_api_utils:get_field(url, Params),
    case validate_url(Url) of
        ok ->
            ManifestUrl = resolve_manifest_url(Url),
            fetch_and_publish(ManifestUrl, AuthorId, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

%% --- URL validation ---

validate_url(undefined) -> {error, <<"url is required">>};
validate_url(<<>>) -> {error, <<"url is required">>};
validate_url(Url) when is_binary(Url) -> ok;
validate_url(_) -> {error, <<"url is required">>}.

%% --- URL resolution ---

resolve_manifest_url(Url) ->
    case binary:match(Url, <<"manifest.json">>) of
        {_, _} ->
            Url;
        nomatch ->
            resolve_github_url(Url)
    end.

resolve_github_url(Url) ->
    case parse_github_url(Url) of
        {ok, Org, Repo, Branch} ->
            <<"https://raw.githubusercontent.com/",
              Org/binary, "/", Repo/binary, "/",
              Branch/binary, "/manifest.json">>;
        not_github ->
            append_manifest(Url)
    end.

parse_github_url(Url) ->
    Stripped = strip_trailing_slash(Url),
    case Stripped of
        <<"https://github.com/", Rest/binary>> ->
            parse_github_path(Rest);
        <<"http://github.com/", Rest/binary>> ->
            parse_github_path(Rest);
        _ ->
            not_github
    end.

parse_github_path(Path) ->
    case binary:split(Path, <<"/">>, [global]) of
        [Org, Repo, <<"tree">>, Branch | _] ->
            {ok, Org, Repo, Branch};
        [Org, Repo] ->
            {ok, Org, Repo, <<"main">>};
        _ ->
            not_github
    end.

strip_trailing_slash(Url) ->
    case binary:last(Url) of
        $/ -> binary:part(Url, 0, byte_size(Url) - 1);
        _ -> Url
    end.

append_manifest(Url) ->
    Stripped = strip_trailing_slash(Url),
    <<Stripped/binary, "/manifest.json">>.

%% @private Resolve OCI image: use explicit value if provided,
%% otherwise derive from GitHub repo URL convention: ghcr.io/{org}/{repo}d
resolve_manifest_oci_image(OciImage, _Org, _ManifestUrl)
  when is_binary(OciImage), byte_size(OciImage) > 0 ->
    OciImage;
resolve_manifest_oci_image(_, _Org, ManifestUrl) ->
    derive_oci_image_from_url(ManifestUrl).

derive_oci_image_from_url(ManifestUrl) ->
    case parse_github_from_raw_url(ManifestUrl) of
        {ok, Org, Repo} ->
            <<"ghcr.io/", Org/binary, "/", Repo/binary, "d">>;
        not_github ->
            undefined
    end.

parse_github_from_raw_url(Url) ->
    case Url of
        <<"https://raw.githubusercontent.com/", Rest/binary>> ->
            case binary:split(Rest, <<"/">>, [global]) of
                [Org, Repo | _] -> {ok, Org, Repo};
                _ -> not_github
            end;
        _ ->
            not_github
    end.

%% --- Fetch and publish ---

fetch_and_publish(ManifestUrl, AuthorId, Req) ->
    case hackney:get(ManifestUrl, [{<<"Accept">>, <<"application/json">>}], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            parse_and_publish(Body, ManifestUrl, AuthorId, Req);
        {ok, 404, _Headers, _Body} ->
            hecate_api_utils:bad_request(<<"manifest.json not found at URL">>, Req);
        {ok, Status, _Headers, _Body} ->
            Msg = iolist_to_binary(io_lib:format("HTTP ~B fetching manifest", [Status])),
            hecate_api_utils:bad_request(Msg, Req);
        {error, Reason} ->
            Msg = iolist_to_binary(io_lib:format("Failed to fetch manifest: ~p", [Reason])),
            hecate_api_utils:bad_request(Msg, Req)
    end.

parse_and_publish(Body, ManifestUrl, AuthorId, Req) ->
    try json:decode(Body) of
        Manifest when is_map(Manifest) ->
            validate_and_publish(Manifest, Body, ManifestUrl, AuthorId, Req);
        _ ->
            hecate_api_utils:bad_request(<<"Invalid JSON in manifest">>, Req)
    catch
        _:_ ->
            hecate_api_utils:bad_request(<<"Invalid JSON in manifest">>, Req)
    end.

validate_and_publish(Manifest, RawBody, ManifestUrl, AuthorId, Req) ->
    Name = maps:get(<<"name">>, Manifest, undefined),
    Version = maps:get(<<"version">>, Manifest, undefined),
    Appstore = maps:get(<<"appstore">>, Manifest, undefined),
    PluginType = maps:get(<<"plugin_type">>, Manifest, <<"container">>),
    case validate_manifest(Name, Version, Appstore) of
        {ok, Org, MaybeOciImage} ->
            MinVsn = maps:get(<<"min_daemon_version">>, Appstore, undefined),
            case check_daemon_version(MinVsn) of
                ok ->
                    resolve_and_dispatch(PluginType, MaybeOciImage, Org, Name, Version,
                                         Manifest, Appstore, RawBody, ManifestUrl, AuthorId, Req);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

resolve_and_dispatch(<<"in_vm">>, _MaybeOciImage, Org, Name, Version,
                     Manifest, Appstore, RawBody, ManifestUrl, AuthorId, Req) ->
    %% In-VM plugins: no OCI image needed, derive/use package_url instead
    ExplicitPackageUrl = maps:get(<<"package_url">>, Appstore, undefined),
    PackageUrl = resolve_package_url(ExplicitPackageUrl, Org, Name, Version, ManifestUrl),
    TrustData = compute_trust_in_vm(RawBody, PackageUrl),
    dispatch_initiate(Name, Version, Org, undefined, PackageUrl, Manifest,
                      Appstore, ManifestUrl, AuthorId, TrustData, Req);
resolve_and_dispatch(_, MaybeOciImage, Org, Name, Version,
                     Manifest, Appstore, RawBody, ManifestUrl, AuthorId, Req) ->
    %% Container plugins: require OCI image, verify it
    OciImage = resolve_manifest_oci_image(MaybeOciImage, Org, ManifestUrl),
    case OciImage of
        undefined ->
            hecate_api_utils:bad_request(
                <<"Cannot determine oci_image: set appstore.oci_image or publish from a GitHub URL">>, Req);
        _ ->
            TrustData = compute_trust(RawBody, OciImage, Version),
            dispatch_initiate(Name, Version, Org, OciImage, undefined, Manifest,
                              Appstore, ManifestUrl, AuthorId, TrustData, Req)
    end.

validate_manifest(undefined, _, _) ->
    {error, <<"manifest missing 'name'">>};
validate_manifest(_, undefined, _) ->
    {error, <<"manifest missing 'version'">>};
validate_manifest(_, _, undefined) ->
    {error, <<"manifest missing 'appstore'">>};
validate_manifest(_, _, Appstore) when is_map(Appstore) ->
    Org = maps:get(<<"org">>, Appstore, undefined),
    OciImage = maps:get(<<"oci_image">>, Appstore, undefined),
    case {Org, OciImage} of
        {undefined, _} -> {error, <<"manifest.appstore missing 'org'">>};
        {_, _} -> {ok, Org, OciImage}
    end;
validate_manifest(_, _, _) ->
    {error, <<"manifest missing 'appstore'">>}.

%% --- Trust verification ---

compute_trust(RawBody, OciImage, Version) ->
    %% 1. SHA-256 checksum of raw manifest body
    ChecksumBin = crypto:hash(sha256, RawBody),
    ChecksumHex = binary:encode_hex(ChecksumBin, lowercase),

    %% 2. Sign checksum with author's Ed25519 key
    {SignatureB64, AuthorMRI} = sign_checksum(ChecksumBin),

    %% 3. Verify OCI image exists via registry HEAD
    FullOciRef = <<OciImage/binary, ":", Version/binary>>,
    {OciVerified, OciDigest} = verify_oci_image(FullOciRef),

    #{
        manifest_checksum => ChecksumHex,
        author_signature => SignatureB64,
        author_mri => AuthorMRI,
        oci_image_verified => OciVerified,
        oci_image_digest => OciDigest
    }.

compute_trust_in_vm(RawBody, PackageUrl) ->
    ChecksumBin = crypto:hash(sha256, RawBody),
    ChecksumHex = binary:encode_hex(ChecksumBin, lowercase),
    {SignatureB64, AuthorMRI} = sign_checksum(ChecksumBin),
    {PkgVerified, PkgSize} = case PackageUrl of
        undefined -> {0, undefined};
        _ -> verify_package_url(PackageUrl)
    end,
    #{
        manifest_checksum => ChecksumHex,
        author_signature => SignatureB64,
        author_mri => AuthorMRI,
        oci_image_verified => PkgVerified,
        oci_image_digest => PkgSize
    }.

resolve_package_url(ExplicitUrl, _Org, _Name, _Version, _ManifestUrl)
  when is_binary(ExplicitUrl), byte_size(ExplicitUrl) > 0 ->
    ExplicitUrl;
resolve_package_url(_, _Org, Name, Version, ManifestUrl) ->
    derive_package_url_from_manifest(ManifestUrl, Version, Name).

derive_package_url_from_manifest(ManifestUrl, Version, Name) ->
    case parse_github_from_raw_url(ManifestUrl) of
        {ok, Org, Repo} ->
            Tag = <<"v", Version/binary>>,
            <<"https://github.com/", Org/binary, "/", Repo/binary,
              "/releases/download/", Tag/binary, "/", Name/binary, ".tar.gz">>;
        not_github ->
            undefined
    end.

verify_package_url(PackageUrl) ->
    case hackney:head(PackageUrl, [{<<"Accept">>, <<"application/octet-stream">>}], <<>>, [{follow_redirect, true}]) of
        {ok, Status, Headers} when Status >= 200, Status < 400 ->
            Size = proplists:get_value(<<"content-length">>, Headers, undefined),
            {1, Size};
        _ ->
            {0, undefined}
    end.

sign_checksum(ChecksumBin) ->
    case hecate_identity:is_initialized() of
        true ->
            case hecate_identity:sign(ChecksumBin) of
                {ok, Signature} ->
                    MRI = case hecate_identity:get_mri() of
                        {ok, M} -> M;
                        _ -> undefined
                    end,
                    {base64:encode(Signature), MRI};
                _ ->
                    {undefined, undefined}
            end;
        false ->
            {undefined, undefined}
    end.

verify_oci_image(OciRef) ->
    case parse_oci_ref(OciRef) of
        {ok, Registry, Path, Tag} ->
            case fetch_registry_token(Registry, Path) of
                {ok, Token} ->
                    check_manifest_head(Registry, Path, Tag, Token);
                _ ->
                    {0, undefined}
            end;
        _ ->
            {0, undefined}
    end.

parse_oci_ref(Ref) ->
    case binary:split(Ref, <<":">>) of
        [ImagePath, Tag] ->
            case binary:split(ImagePath, <<"/">>) of
                [Registry | Rest] when Rest =/= [] ->
                    Path = iolist_to_binary(lists:join(<<"/">>, Rest)),
                    {ok, Registry, Path, Tag};
                _ ->
                    {error, invalid_ref}
            end;
        _ ->
            {error, invalid_ref}
    end.

fetch_registry_token(Registry, Path) ->
    TokenUrl = <<"https://", Registry/binary,
                 "/token?service=", Registry/binary,
                 "&scope=repository:", Path/binary, ":pull">>,
    case hackney:get(TokenUrl, [], <<>>, [with_body]) of
        {ok, 200, _, TokenBody} ->
            try json:decode(TokenBody) of
                #{<<"token">> := Token} -> {ok, Token};
                _ -> {error, no_token}
            catch _:_ -> {error, parse_error}
            end;
        _ ->
            {error, token_fetch_failed}
    end.

check_manifest_head(Registry, Path, Tag, Token) ->
    Url = <<"https://", Registry/binary, "/v2/", Path/binary,
            "/manifests/", Tag/binary>>,
    Headers = [
        {<<"Authorization">>, <<"Bearer ", Token/binary>>},
        {<<"Accept">>, <<"application/vnd.oci.image.manifest.v1+json">>}
    ],
    case hackney:head(Url, Headers, <<>>, []) of
        {ok, 200, RespHeaders} ->
            Digest = proplists:get_value(<<"docker-content-digest">>, RespHeaders, undefined),
            {1, Digest};
        _ ->
            {0, undefined}
    end.

%% --- Daemon version check ---

check_daemon_version(undefined) -> ok;
check_daemon_version(MinVsn) when is_binary(MinVsn) ->
    {ok, DaemonVsn} = application:get_key(hecate, vsn),
    case compare_versions(list_to_binary(DaemonVsn), MinVsn) of
        lt ->
            Msg = iolist_to_binary(io_lib:format(
                "daemon version ~s is below minimum ~s required by plugin",
                [DaemonVsn, MinVsn])),
            {error, Msg};
        _ ->
            ok
    end;
check_daemon_version(_) -> ok.

compare_versions(A, B) ->
    PartsA = parse_version(A),
    PartsB = parse_version(B),
    compare_parts(PartsA, PartsB).

parse_version(Vsn) ->
    Parts = binary:split(Vsn, <<".">>, [global]),
    [binary_to_integer(P) || P <- Parts].

compare_parts([], []) -> eq;
compare_parts([], _) -> lt;
compare_parts(_, []) -> gt;
compare_parts([H | TA], [H | TB]) -> compare_parts(TA, TB);
compare_parts([HA | _], [HB | _]) when HA < HB -> lt;
compare_parts([HA | _], [HB | _]) when HA > HB -> gt.

%% --- Dispatch initiate_offering_v1 ---

dispatch_initiate(Name, Version, Org, OciImage, PackageUrl, Manifest,
                  Appstore, ManifestUrl, AuthorId, TrustData, Req) ->
    PluginId = <<Org/binary, "/", Name/binary>>,
    FullOciImage = case OciImage of
        undefined -> undefined;
        _ -> <<OciImage/binary, ":", Version/binary>>
    end,

    PluginType = maps:get(<<"plugin_type">>, Manifest, <<"container">>),
    CallbackModule = maps:get(<<"callback_module">>, Manifest, undefined),

    CmdParams = #{
        author_id          => AuthorId,
        plugin_id          => PluginId,
        plugin_name        => maps:get(<<"display_name">>, Manifest, Name),
        description        => maps:get(<<"description">>, Manifest, undefined),
        icon               => maps:get(<<"icon">>, Manifest, undefined),
        group_name         => maps:get(<<"group_name">>, Appstore, undefined),
        github_repo        => maps:get(<<"github_repo">>, Appstore, undefined),
        plugin_type        => PluginType,
        callback_module    => CallbackModule,
        oci_image          => FullOciImage,
        package_url        => PackageUrl,
        org                => Org,
        version            => Version,
        manifest_tag       => maps:get(<<"manifest_tag">>, Appstore, undefined),
        tags               => format_tags(maps:get(<<"tags">>, Appstore, undefined)),
        homepage           => maps:get(<<"homepage">>, Manifest, undefined),
        min_daemon_version => maps:get(<<"min_daemon_version">>, Appstore, undefined),
        publisher_identity => maps:get(author_mri, TrustData, undefined),
        selling_formula    => maps:get(<<"selling_formula">>, Appstore, undefined),
        license_type       => maps:get(<<"license_type">>, Appstore, undefined),
        fee_cents          => maps:get(<<"fee_cents">>, Appstore, undefined),
        fee_currency       => maps:get(<<"fee_currency">>, Appstore, undefined),
        duration_days      => maps:get(<<"duration_days">>, Appstore, undefined),
        node_limit         => maps:get(<<"node_limit">>, Appstore, undefined),
        %% Trust verification fields
        manifest_url       => ManifestUrl,
        manifest_checksum  => maps:get(manifest_checksum, TrustData),
        author_signature   => maps:get(author_signature, TrustData),
        oci_image_verified => maps:get(oci_image_verified, TrustData),
        oci_image_digest   => maps:get(oci_image_digest, TrustData)
    },

    case initiate_offering_v1:new(CmdParams) of
        {ok, Cmd} ->
            do_dispatch(Cmd, TrustData, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

do_dispatch(Cmd, TrustData, Req) ->
    OfferingId = initiate_offering_v1:get_offering_id(Cmd),
    case maybe_initiate_offering:dispatch(Cmd) of
        {ok, _Version, _EventMaps} ->
            case auto_publish(OfferingId) of
                {ok, PublishVersion} ->
                    hecate_api_utils:json_ok(201, #{
                        offering_id        => OfferingId,
                        plugin_id          => initiate_offering_v1:get_plugin_id(Cmd),
                        plugin_name        => initiate_offering_v1:get_plugin_name(Cmd),
                        oci_image          => initiate_offering_v1:get_oci_image(Cmd),
                        manifest_checksum  => maps:get(manifest_checksum, TrustData),
                        author_signature   => maps:get(author_signature, TrustData),
                        oci_image_verified => maps:get(oci_image_verified, TrustData),
                        oci_image_digest   => maps:get(oci_image_digest, TrustData),
                        version            => PublishVersion,
                        status             => <<"published">>
                    }, Req);
                {error, Reason} ->
                    logger:error("[publish_from_url] Auto-publish failed for ~s: ~p",
                                 [OfferingId, Reason]),
                    hecate_api_utils:json_error(500,
                        <<"Offering initiated but auto-publish failed">>, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

auto_publish(OfferingId) ->
    {ok, AnnounceCmd} = announce_offering_v1:new(#{offering_id => OfferingId}),
    case maybe_announce_offering:dispatch(AnnounceCmd) of
        {ok, _, _} ->
            {ok, PublishCmd} = publish_offering_v1:new(#{offering_id => OfferingId}),
            case maybe_publish_offering:dispatch(PublishCmd) of
                {ok, Version, _} -> {ok, Version};
                {error, _} = Err -> Err
            end;
        {error, _} = Err -> Err
    end.

format_tags(undefined) -> undefined;
format_tags(Tags) when is_list(Tags) ->
    iolist_to_binary(lists:join(<<",">>, Tags));
format_tags(Tags) when is_binary(Tags) -> Tags;
format_tags(_) -> undefined.
