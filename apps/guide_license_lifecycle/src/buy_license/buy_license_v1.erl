%%% @doc buy_license_v1 command
%%% Acquires a license for a marketplace plugin.
-module(buy_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_user_id/1, get_plugin_id/1,
         get_plugin_name/1, get_oci_image/1]).

-record(buy_license_v1, {
    license_id  :: binary(),
    user_id     :: binary(),
    plugin_id   :: binary(),
    plugin_name :: binary() | undefined,
    oci_image   :: binary() | undefined
}).

-export_type([buy_license_v1/0]).
-opaque buy_license_v1() :: #buy_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, buy_license_v1()} | {error, term()}.
new(#{user_id := UserId, plugin_id := PluginId} = Params) ->
    LicenseId = <<"license-", UserId/binary, "-", PluginId/binary>>,
    {ok, #buy_license_v1{
        license_id = LicenseId,
        user_id = UserId,
        plugin_id = PluginId,
        plugin_name = maps:get(plugin_name, Params, undefined),
        oci_image = maps:get(oci_image, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(buy_license_v1()) -> {ok, buy_license_v1()} | {error, term()}.
validate(#buy_license_v1{user_id = UserId}) when
    not is_binary(UserId); byte_size(UserId) =:= 0 ->
    {error, invalid_user_id};
validate(#buy_license_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#buy_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(buy_license_v1()) -> map().
to_map(#buy_license_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"buy_license">>,
        <<"license_id">> => Cmd#buy_license_v1.license_id,
        <<"user_id">> => Cmd#buy_license_v1.user_id,
        <<"plugin_id">> => Cmd#buy_license_v1.plugin_id,
        <<"plugin_name">> => Cmd#buy_license_v1.plugin_name,
        <<"oci_image">> => Cmd#buy_license_v1.oci_image
    }.

-spec from_map(map()) -> {ok, buy_license_v1()} | {error, term()}.
from_map(Map) ->
    UserId = hecate_api_utils:get_field(user_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case {UserId, PluginId} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            LicenseId = <<"license-", UserId/binary, "-", PluginId/binary>>,
            {ok, #buy_license_v1{
                license_id = LicenseId,
                user_id = UserId,
                plugin_id = PluginId,
                plugin_name = hecate_api_utils:get_field(plugin_name, Map, undefined),
                oci_image = hecate_api_utils:get_field(oci_image, Map, undefined)
            }}
    end.

%% Accessors
-spec get_license_id(buy_license_v1()) -> binary().
get_license_id(#buy_license_v1{license_id = V}) -> V.

-spec get_user_id(buy_license_v1()) -> binary().
get_user_id(#buy_license_v1{user_id = V}) -> V.

-spec get_plugin_id(buy_license_v1()) -> binary().
get_plugin_id(#buy_license_v1{plugin_id = V}) -> V.

-spec get_plugin_name(buy_license_v1()) -> binary() | undefined.
get_plugin_name(#buy_license_v1{plugin_name = V}) -> V.

-spec get_oci_image(buy_license_v1()) -> binary() | undefined.
get_oci_image(#buy_license_v1{oci_image = V}) -> V.
