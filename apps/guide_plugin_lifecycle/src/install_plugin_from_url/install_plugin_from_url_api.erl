%%% @doc API handler: POST /api/node/plugins/install-from-url
%%%
%%% Fetches a manifest.json from a URL (e.g. GitHub repo),
%%% derives plugin install parameters, and dispatches the
%%% existing install_plugin_v1 command pipeline.
%%% @end
-module(install_plugin_from_url_api).

-export([init/2, routes/0]).

routes() -> [{"/api/node/plugins/install-from-url", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_install_from_url(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_install_from_url(Params, Req) ->
    Url = hecate_api_utils:get_field(url, Params),
    case validate_url(Url) of
        ok ->
            ManifestUrl = resolve_manifest_url(Url),
            fetch_and_install(ManifestUrl, Req);
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

%% --- Fetch and install ---

fetch_and_install(ManifestUrl, Req) ->
    case hackney:get(ManifestUrl, [{<<"Accept">>, <<"application/json">>}], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            parse_and_dispatch(Body, Req);
        {ok, 404, _Headers, _Body} ->
            hecate_api_utils:bad_request(<<"manifest.json not found at URL">>, Req);
        {ok, Status, _Headers, _Body} ->
            Msg = iolist_to_binary(io_lib:format("HTTP ~B fetching manifest", [Status])),
            hecate_api_utils:bad_request(Msg, Req);
        {error, Reason} ->
            Msg = iolist_to_binary(io_lib:format("Failed to fetch manifest: ~p", [Reason])),
            hecate_api_utils:bad_request(Msg, Req)
    end.

parse_and_dispatch(Body, Req) ->
    try json:decode(Body) of
        Manifest when is_map(Manifest) ->
            validate_and_dispatch(Manifest, Req);
        _ ->
            hecate_api_utils:bad_request(<<"Invalid JSON in manifest">>, Req)
    catch
        _:_ ->
            hecate_api_utils:bad_request(<<"Invalid JSON in manifest">>, Req)
    end.

validate_and_dispatch(Manifest, Req) ->
    Name = maps:get(<<"name">>, Manifest, undefined),
    Version = maps:get(<<"version">>, Manifest, undefined),
    Appstore = maps:get(<<"appstore">>, Manifest, undefined),
    case validate_manifest(Name, Version, Appstore) of
        {ok, Org, OciImage} ->
            MinVsn = maps:get(<<"min_daemon_version">>, Appstore, undefined),
            case check_daemon_version(MinVsn) of
                ok ->
                    dispatch_install(Name, Version, Org, OciImage, Manifest, Req);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
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
        {_, undefined} -> {error, <<"manifest.appstore missing 'oci_image'">>};
        {_, _} -> {ok, Org, OciImage}
    end;
validate_manifest(_, _, _) ->
    {error, <<"manifest missing 'appstore'">>}.

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

dispatch_install(Name, Version, Org, OciImage, Manifest, Req) ->
    PluginId = <<Org/binary, "/", Name/binary>>,
    FullOciImage = <<OciImage/binary, ":", Version/binary>>,
    CmdParams = #{
        plugin_id         => PluginId,
        name              => Name,
        oci_image         => FullOciImage,
        installed_version => Version,
        license_id        => undefined
    },
    case install_plugin_v1:new(CmdParams) of
        {ok, Cmd} ->
            do_dispatch(Cmd, Manifest, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

do_dispatch(Cmd, Manifest, Req) ->
    case maybe_install_plugin:dispatch(Cmd) of
        {ok, EventVersion, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                plugin_id         => install_plugin_v1:get_plugin_id(Cmd),
                name              => install_plugin_v1:get_name(Cmd),
                oci_image         => install_plugin_v1:get_oci_image(Cmd),
                installed_version => install_plugin_v1:get_installed_version(Cmd),
                version           => EventVersion,
                events            => EventMaps,
                manifest          => Manifest
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
