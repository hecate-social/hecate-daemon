%%% @doc Periodically checks GitHub Releases API for new plugin versions.
%%%
%%% Polls all published offerings that have a raw.githubusercontent.com
%%% manifest_url, compares their version against the latest GitHub release,
%%% and dispatches amend_offering_v1 when a newer version is found.
%%% @end
-module(refresh_offering_versions).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_info/2, handle_cast/2, handle_call/3, terminate/2]).

-define(INITIAL_DELAY_MS, 30000).
-define(INTERVAL_MS, 600000).
-define(INTER_OFFERING_DELAY_MS, 2000).

%% --- Public API ---

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% --- gen_server callbacks ---

init([]) ->
    erlang:send_after(?INITIAL_DELAY_MS, self(), refresh),
    {ok, #{}}.

handle_info(refresh, State) ->
    do_refresh(),
    erlang:send_after(?INTERVAL_MS, self(), refresh),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.

handle_cast(_Msg, State) -> {noreply, State}.
handle_call(_Msg, _From, State) -> {reply, ok, State}.
terminate(_Reason, _State) -> ok.

%% --- Internal ---

do_refresh() ->
    case project_license_offerings_store:browse_offerings() of
        {ok, Offerings} ->
            GithubOfferings = [O || O <- Offerings, is_github_offering(O)],
            logger:info("[refresh_versions] Checking ~B GitHub-hosted offerings",
                        [length(GithubOfferings)]),
            check_offerings(GithubOfferings);
        {error, Reason} ->
            logger:warning("[refresh_versions] Failed to browse offerings: ~p", [Reason])
    end.

is_github_offering(#{manifest_url := Url}) when is_binary(Url) ->
    case binary:match(Url, <<"raw.githubusercontent.com">>) of
        {_, _} -> true;
        nomatch -> false
    end;
is_github_offering(_) ->
    false.

check_offerings([]) -> ok;
check_offerings([Offering | Rest]) ->
    case check_one_offering(Offering) of
        rate_limited ->
            logger:warning("[refresh_versions] Rate limited, skipping remaining offerings"),
            ok;
        _ ->
            case Rest of
                [] -> ok;
                _ ->
                    timer:sleep(?INTER_OFFERING_DELAY_MS),
                    check_offerings(Rest)
            end
    end.

check_one_offering(#{manifest_url := ManifestUrl, offering_id := OfferingId,
                     version := CurrentVersion} = Offering) ->
    case publish_from_url_api:parse_github_from_raw_url(ManifestUrl) of
        {ok, Org, Repo} ->
            case fetch_latest_release(Org, Repo) of
                {ok, LatestVersion} ->
                    case publish_from_url_api:compare_versions(LatestVersion, CurrentVersion) of
                        gt ->
                            logger:info("[refresh_versions] ~s: ~s -> ~s available",
                                        [OfferingId, CurrentVersion, LatestVersion]),
                            fetch_and_amend(Org, Repo, LatestVersion, Offering);
                        _ ->
                            ok
                    end;
                rate_limited ->
                    rate_limited;
                {error, Reason} ->
                    logger:warning("[refresh_versions] ~s: GitHub API error: ~p",
                                   [OfferingId, Reason]),
                    ok
            end;
        not_github ->
            ok
    end.

fetch_latest_release(Org, Repo) ->
    Url = <<"https://api.github.com/repos/", Org/binary, "/", Repo/binary, "/releases/latest">>,
    Headers = github_headers(),
    case hackney:get(Url, Headers, <<>>, [with_body]) of
        {ok, 200, _RespHeaders, Body} ->
            try json:decode(Body) of
                #{<<"tag_name">> := TagName} ->
                    {ok, strip_v_prefix(TagName)};
                _ ->
                    {error, no_tag_name}
            catch _:_ ->
                {error, invalid_json}
            end;
        {ok, 404, _, _} ->
            {error, no_releases};
        {ok, Status, _, _} when Status =:= 403; Status =:= 429 ->
            rate_limited;
        {ok, Status, _, _} ->
            {error, {http_status, Status}};
        {error, Reason} ->
            {error, Reason}
    end.

strip_v_prefix(<<"v", Rest/binary>>) -> Rest;
strip_v_prefix(<<"V", Rest/binary>>) -> Rest;
strip_v_prefix(Other) -> Other.

fetch_and_amend(Org, Repo, Version, #{offering_id := OfferingId, name := Name}) ->
    Tag = <<"v", Version/binary>>,
    ManifestUrl = <<"https://raw.githubusercontent.com/",
                    Org/binary, "/", Repo/binary, "/",
                    Tag/binary, "/manifest.json">>,
    case hackney:get(ManifestUrl, [{<<"Accept">>, <<"application/json">>}], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            try json:decode(Body) of
                Manifest when is_map(Manifest) ->
                    do_amend(OfferingId, Org, Name, Version, ManifestUrl, Body, Manifest);
                _ ->
                    logger:warning("[refresh_versions] ~s: Invalid manifest JSON", [OfferingId])
            catch _:_ ->
                logger:warning("[refresh_versions] ~s: Failed to parse manifest", [OfferingId])
            end;
        {ok, Status, _, _} ->
            logger:warning("[refresh_versions] ~s: manifest fetch HTTP ~B for tag ~s",
                           [OfferingId, Status, Tag]);
        {error, Reason} ->
            logger:warning("[refresh_versions] ~s: manifest fetch error: ~p", [OfferingId, Reason])
    end,
    ok.

do_amend(OfferingId, Org, Name, Version, ManifestUrl, RawBody, Manifest) ->
    PluginType = maps:get(<<"plugin_type">>, Manifest, <<"container">>),
    Appstore = maps:get(<<"appstore">>, Manifest, #{}),
    {PackageUrl, OciImageFull, TrustData} = case PluginType of
        <<"in_vm">> ->
            ExplicitPkgUrl = maps:get(<<"package_url">>, Appstore, undefined),
            PUrl = publish_from_url_api:resolve_package_url(
                ExplicitPkgUrl, Org, Name, Version, ManifestUrl),
            TD = publish_from_url_api:compute_trust_in_vm(RawBody, PUrl),
            {PUrl, undefined, TD};
        _ ->
            OciBase = resolve_oci_image(Appstore, Org, ManifestUrl),
            TD = publish_from_url_api:compute_trust(RawBody, OciBase, Version),
            OciFull = case OciBase of
                undefined -> undefined;
                _ -> <<OciBase/binary, ":", Version/binary>>
            end,
            {undefined, OciFull, TD}
    end,
    CmdParams = #{
        offering_id        => OfferingId,
        version            => Version,
        manifest_url       => ManifestUrl,
        manifest_checksum  => maps:get(manifest_checksum, TrustData),
        author_signature   => maps:get(author_signature, TrustData),
        oci_image_verified => maps:get(oci_image_verified, TrustData),
        oci_image_digest   => maps:get(oci_image_digest, TrustData),
        package_url        => PackageUrl,
        oci_image          => OciImageFull
    },
    case amend_offering_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_amend_offering:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[refresh_versions] ~s: amended to v~s", [OfferingId, Version]);
                {error, Reason} ->
                    logger:warning("[refresh_versions] ~s: amend dispatch failed: ~p",
                                   [OfferingId, Reason])
            end;
        {error, Reason} ->
            logger:warning("[refresh_versions] ~s: amend command invalid: ~p",
                           [OfferingId, Reason])
    end.

resolve_oci_image(Appstore, _Org, ManifestUrl) ->
    case maps:get(<<"oci_image">>, Appstore, undefined) of
        undefined ->
            case publish_from_url_api:parse_github_from_raw_url(ManifestUrl) of
                {ok, O, R} -> <<"ghcr.io/", O/binary, "/", R/binary, "d">>;
                not_github -> undefined
            end;
        Img when is_binary(Img), byte_size(Img) > 0 ->
            Img;
        _ ->
            undefined
    end.

github_headers() ->
    Base = [{<<"Accept">>, <<"application/vnd.github+json">>},
            {<<"User-Agent">>, <<"hecate-daemon">>}],
    case os:getenv("GITHUB_TOKEN") of
        false -> Base;
        "" -> Base;
        Token ->
            TokenBin = list_to_binary(Token),
            [{<<"Authorization">>, <<"token ", TokenBin/binary>>} | Base]
    end.
