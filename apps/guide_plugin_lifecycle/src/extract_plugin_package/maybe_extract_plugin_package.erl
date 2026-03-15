%%% @doc Handler for extract_plugin_package_v1 command.
%%%
%%% Extracts a plugin .tar.gz archive to ~/.hecate/plugins/{name}/.
%%% Downloads from package_url if not already present locally.
%%%
%%% Business rules:
%%%   - Plugin must be installed
%%%   - package_url must be a valid binary URL
%%%   - Tarball download must succeed
%%%   - Extraction must succeed (ebin/ must exist after)
-module(maybe_extract_plugin_package).

-include("plugin_state.hrl").
-include_lib("evoq/include/evoq.hrl").
-include_lib("hecate_sdk/include/hecate_plugin.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(extract_plugin_package_v1:extract_plugin_package_v1()) ->
    {ok, [plugin_package_extracted_v1:plugin_package_extracted_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(extract_plugin_package_v1:extract_plugin_package_v1(), term()) ->
    {ok, [plugin_package_extracted_v1:plugin_package_extracted_v1()]} | {error, term()}.
handle(Cmd, #plugin_state{callback_module = StateCallback}) ->
    do_extract(Cmd, StateCallback);
handle(Cmd, _State) ->
    do_extract(Cmd, undefined).

do_extract(Cmd, StateCallback) ->
    PluginId = extract_plugin_package_v1:get_plugin_id(Cmd),
    PackageUrl = extract_plugin_package_v1:get_package_url(Cmd),
    CallbackModule = resolve_callback(extract_plugin_package_v1:get_callback_module(Cmd), StateCallback),
    do_extract_with_url(PluginId, PackageUrl, CallbackModule).

%% Guard: package_url must be a non-empty binary
do_extract_with_url(_PluginId, Url, _CB) when not is_binary(Url); byte_size(Url) =:= 0 ->
    {error, {missing_package_url, Url}};
do_extract_with_url(PluginId, PackageUrl, CallbackModule) ->
    hecate_plugin_paths:ensure_layout(PluginId),
    BaseDir = hecate_plugin_paths:base_dir(PluginId),
    TarFilename = filename:basename(binary_to_list(PackageUrl)),
    TarPath = filename:join(BaseDir, TarFilename),
    do_download_and_extract(PluginId, PackageUrl, BaseDir, TarPath, CallbackModule).

do_download_and_extract(PluginId, PackageUrl, BaseDir, TarPath, CallbackModule) ->
    report_progress(PluginId, #{status => downloading, percent => 0,
                                line => <<"Downloading package...">>}),
    case ensure_tarball(PackageUrl, TarPath) of
        ok ->
            report_progress(PluginId, #{status => extracting, percent => 50,
                                        line => <<"Extracting package...">>}),
            do_extract_tarball(PluginId, BaseDir, TarPath, CallbackModule);
        {error, _} = Err ->
            report_progress(PluginId, #{status => error, reason => Err}),
            Err
    end.

ensure_tarball(PackageUrl, TarPath) ->
    ensure_tarball(PackageUrl, TarPath, filelib:is_regular(TarPath)).

ensure_tarball(_Url, TarPath, true) ->
    logger:info("[extract] Tarball already present: ~s", [TarPath]),
    ok;
ensure_tarball(Url, TarPath, false) ->
    logger:info("[extract] Downloading ~s to ~s", [Url, TarPath]),
    case download_package(Url, TarPath) of
        ok -> ok;
        {error, DlReason} ->
            logger:error("[extract] Download failed: ~p", [DlReason]),
            {error, {download_failed, DlReason}}
    end.

%% Write progress to plugin_pull_progress ETS (shared with OCI pull status).
%% The table is created by on_oci_pull_started_pull_image at boot.
report_progress(PluginId, Progress) ->
    try ets:insert(plugin_pull_progress, {PluginId, Progress})
    catch error:badarg -> ok  %% table not yet created
    end.

do_extract_tarball(PluginId, BaseDir, TarPath, CallbackModule) ->
    logger:info("[extract] Extracting ~s to ~s", [TarPath, BaseDir]),
    case erl_tar:extract(TarPath, [compressed, {cwd, BaseDir}]) of
        ok -> verify_ebin(PluginId, BaseDir, CallbackModule);
        {error, Reason} ->
            logger:error("[extract] Failed to extract ~s: ~p", [TarPath, Reason]),
            {error, {extraction_failed, Reason}}
    end.

verify_ebin(PluginId, BaseDir, CallbackModule) ->
    EbinDir = filename:join(BaseDir, "ebin"),
    case filelib:is_dir(EbinDir) of
        true ->
            logger:info("[extract] Plugin ~s extracted successfully", [PluginId]),
            report_progress(PluginId, #{status => complete, percent => 100}),
            Event = plugin_package_extracted_v1:new(#{
                plugin_id => PluginId,
                callback_module => CallbackModule
            }),
            {ok, [Event]};
        false ->
            logger:error("[extract] No ebin/ after extraction of ~s", [PluginId]),
            report_progress(PluginId, #{status => error,
                                        reason => no_ebin_after_extraction}),
            {error, {no_ebin_after_extraction, PluginId}}
    end.

resolve_callback(undefined, StateCallback) -> StateCallback;
resolve_callback(null, StateCallback) -> StateCallback;
resolve_callback(CmdCallback, _) -> CmdCallback.

download_package(Url, DestPath) ->
    case hackney:get(Url, [], <<>>, [{follow_redirect, true}, with_body]) of
        {ok, 200, _Headers, Body} ->
            file:write_file(DestPath, Body);
        {ok, Status, _Headers, _Body} ->
            {error, {http_status, Status}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(extract_plugin_package_v1:extract_plugin_package_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = extract_plugin_package_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = extract_plugin_package,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = extract_plugin_package_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => plugin_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => plugins_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
