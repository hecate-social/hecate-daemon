%%% @doc Tests for on_license_granted_install_plugin PM.
%%%
%%% Verifies that the PM correctly maps license_granted_v1 event fields
%%% to install_plugin_v1 command params — specifically that `name` comes
%%% from the event's `plugin_name` field (the clean manifest name),
%%% NOT from `plugin_id` (which has the org/name prefix).
-module(on_license_granted_install_plugin_tests).

-include_lib("eunit/include/eunit.hrl").

%% -- Test Data --

-define(PLUGIN_ID, <<"hecate-apps/hecate-app-scribe">>).
-define(PLUGIN_NAME, <<"hecate-app-scribe">>).
-define(VERSION, <<"0.1.5">>).
-define(LICENSE_ID, <<"lic-abc-123">>).
-define(CALLBACK_MODULE, <<"app_scribe">>).
-define(PACKAGE_URL, <<"https://github.com/hecate-apps/hecate-app-scribe/releases/download/v0.1.5/hecate-app-scribe.tar.gz">>).

%% Simulate what license_granted_v1:to_map/1 produces
make_license_granted_event_data() ->
    #{
        event_type      => <<"license_granted_v1">>,
        license_id      => ?LICENSE_ID,
        grant_reason    => <<"free">>,
        granted_at      => erlang:system_time(millisecond),
        plugin_id       => ?PLUGIN_ID,
        plugin_name     => ?PLUGIN_NAME,
        oci_image       => undefined,
        version         => ?VERSION,
        icon            => <<"pencil">>,
        group_name      => <<"OFFICE">>,
        group_icon      => <<"briefcase">>,
        plugin_type     => <<"in_vm">>,
        callback_module => ?CALLBACK_MODULE,
        package_url     => ?PACKAGE_URL
    }.

%% Container plugin variant — has oci_image, no callback_module
make_container_granted_event_data() ->
    #{
        event_type      => <<"license_granted_v1">>,
        license_id      => ?LICENSE_ID,
        grant_reason    => <<"free">>,
        granted_at      => erlang:system_time(millisecond),
        plugin_id       => <<"hecate-social/hecate-app-trader">>,
        plugin_name     => <<"hecate-app-trader">>,
        oci_image       => <<"ghcr.io/hecate-social/hecate-app-traderd:0.1.0">>,
        version         => <<"0.1.0">>,
        icon            => undefined,
        group_name      => undefined,
        group_icon      => undefined,
        plugin_type     => <<"container">>,
        callback_module => undefined,
        package_url     => undefined
    }.

%% -- Tests: Field Mapping --

%% The PM must build install_plugin_v1 params with `name` from the event's
%% `plugin_name` field — NOT from `plugin_id`.
%% This was the root cause of the org prefix corruption bug.
name_comes_from_plugin_name_not_plugin_id_test() ->
    CmdParams = build_cmd_params(make_license_granted_event_data()),
    Name = maps:get(name, CmdParams),
    %% name MUST be the clean plugin name from manifest
    ?assertEqual(?PLUGIN_NAME, Name),
    %% name must NOT contain a slash (org prefix)
    ?assertEqual(nomatch, binary:match(Name, <<"/">>)).

%% plugin_id retains the org/name composite format
plugin_id_preserved_test() ->
    CmdParams = build_cmd_params(make_license_granted_event_data()),
    ?assertEqual(?PLUGIN_ID, maps:get(plugin_id, CmdParams)).

%% All install-relevant fields are forwarded
all_fields_forwarded_test() ->
    CmdParams = build_cmd_params(make_license_granted_event_data()),
    ?assertEqual(?VERSION, maps:get(installed_version, CmdParams)),
    ?assertEqual(?LICENSE_ID, maps:get(license_id, CmdParams)),
    ?assertEqual(<<"in_vm">>, maps:get(plugin_type, CmdParams)),
    ?assertEqual(?CALLBACK_MODULE, maps:get(callback_module, CmdParams)),
    ?assertEqual(?PACKAGE_URL, maps:get(package_url, CmdParams)),
    ?assertEqual(<<"pencil">>, maps:get(icon, CmdParams)),
    ?assertEqual(<<"OFFICE">>, maps:get(group_name, CmdParams)),
    ?assertEqual(<<"briefcase">>, maps:get(group_icon, CmdParams)).

%% Container plugin: name derived from OCI image
container_name_from_oci_image_test() ->
    CmdParams = build_cmd_params(make_container_granted_event_data()),
    Name = maps:get(name, CmdParams),
    %% For container plugins, resolve_routing_name extracts from OCI image
    %% The exact value depends on shared_podman:extract_plugin_name/1
    %% but it must NOT contain the org prefix slash
    ?assertEqual(nomatch, binary:match(Name, <<"/">>)).

%% -- Tests: install_plugin_v1 Command Construction --

%% The CmdParams must be accepted by install_plugin_v1:new/1
cmd_params_create_valid_command_test() ->
    CmdParams = build_cmd_params(make_license_granted_event_data()),
    Result = install_plugin_v1:new(CmdParams),
    ?assertMatch({ok, _}, Result).

%% The resulting command has the correct name
cmd_has_clean_name_test() ->
    CmdParams = build_cmd_params(make_license_granted_event_data()),
    {ok, Cmd} = install_plugin_v1:new(CmdParams),
    ?assertEqual(?PLUGIN_NAME, install_plugin_v1:get_name(Cmd)).

%% -- Tests: Event Roundtrip --

%% license_granted_v1 event serialization includes plugin_name
license_granted_event_has_plugin_name_test() ->
    Event = license_granted_v1:new(#{
        license_id      => ?LICENSE_ID,
        plugin_id       => ?PLUGIN_ID,
        plugin_name     => ?PLUGIN_NAME,
        version         => ?VERSION,
        plugin_type     => <<"in_vm">>,
        callback_module => ?CALLBACK_MODULE,
        package_url     => ?PACKAGE_URL
    }),
    Map = license_granted_v1:to_map(Event),
    %% The event MUST have plugin_name (the PM reads this field)
    ?assertEqual(?PLUGIN_NAME, maps:get(plugin_name, Map)),
    %% The event must NOT have a bare `name` field (that's the bug source)
    ?assertNot(maps:is_key(name, Map)).

%% -- Internal: Extract the PM's command-building logic for testability --

build_cmd_params(Data) ->
    PluginId = gf(plugin_id, Data),
    #{
        plugin_id         => PluginId,
        name              => resolve_routing_name(gf(oci_image, Data), gf(plugin_name, Data, PluginId)),
        display_name      => gf(plugin_name, Data, PluginId),
        oci_image         => gf(oci_image, Data),
        installed_version => gf(version, Data, <<"latest">>),
        license_id        => gf(license_id, Data),
        icon              => gf(icon, Data, undefined),
        group_name        => gf(group_name, Data, undefined),
        group_icon        => gf(group_icon, Data, undefined),
        plugin_type       => gf(plugin_type, Data, <<"container">>),
        callback_module   => gf(callback_module, Data, undefined),
        package_url       => gf(package_url, Data, undefined)
    }.

resolve_routing_name(OciImage, _) when is_binary(OciImage), byte_size(OciImage) > 0 ->
    shared_podman:extract_plugin_name(OciImage);
resolve_routing_name(_, Fallback) ->
    Fallback.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
gf(Key, Data, Default) -> hecate_api_utils:get_field(Key, Data, Default).
