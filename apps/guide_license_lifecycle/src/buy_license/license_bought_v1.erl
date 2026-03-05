%%% @doc license_bought_v1 event
%%% Emitted when a plugin license is successfully acquired.
-module(license_bought_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_user_id/1, get_plugin_id/1,
         get_plugin_name/1, get_oci_image/1, get_granted_at/1]).

-record(license_bought_v1, {
    license_id  :: binary(),
    user_id     :: binary(),
    plugin_id   :: binary(),
    plugin_name :: binary() | undefined,
    oci_image   :: binary() | undefined,
    granted_at  :: integer()
}).

-export_type([license_bought_v1/0]).
-opaque license_bought_v1() :: #license_bought_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_bought_v1().
new(#{license_id := LicenseId, user_id := UserId, plugin_id := PluginId} = Params) ->
    #license_bought_v1{
        license_id = LicenseId,
        user_id = UserId,
        plugin_id = PluginId,
        plugin_name = maps:get(plugin_name, Params, undefined),
        oci_image = maps:get(oci_image, Params, undefined),
        granted_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_bought_v1()) -> map().
to_map(#license_bought_v1{} = E) ->
    #{
        event_type => <<"license_bought_v1">>,
        license_id => E#license_bought_v1.license_id,
        user_id => E#license_bought_v1.user_id,
        plugin_id => E#license_bought_v1.plugin_id,
        plugin_name => E#license_bought_v1.plugin_name,
        oci_image => E#license_bought_v1.oci_image,
        granted_at => E#license_bought_v1.granted_at
    }.

-spec from_map(map()) -> {ok, license_bought_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    UserId = hecate_api_utils:get_field(user_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case {LicenseId, UserId, PluginId} of
        {undefined, _, _} -> {error, invalid_event};
        {_, undefined, _} -> {error, invalid_event};
        {_, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #license_bought_v1{
                license_id = LicenseId,
                user_id = UserId,
                plugin_id = PluginId,
                plugin_name = hecate_api_utils:get_field(plugin_name, Map, undefined),
                oci_image = hecate_api_utils:get_field(oci_image, Map, undefined),
                granted_at = hecate_api_utils:get_field(granted_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(license_bought_v1()) -> binary().
get_license_id(#license_bought_v1{license_id = V}) -> V.

-spec get_user_id(license_bought_v1()) -> binary().
get_user_id(#license_bought_v1{user_id = V}) -> V.

-spec get_plugin_id(license_bought_v1()) -> binary().
get_plugin_id(#license_bought_v1{plugin_id = V}) -> V.

-spec get_plugin_name(license_bought_v1()) -> binary() | undefined.
get_plugin_name(#license_bought_v1{plugin_name = V}) -> V.

-spec get_oci_image(license_bought_v1()) -> binary() | undefined.
get_oci_image(#license_bought_v1{oci_image = V}) -> V.

-spec get_granted_at(license_bought_v1()) -> integer().
get_granted_at(#license_bought_v1{granted_at = V}) -> V.
