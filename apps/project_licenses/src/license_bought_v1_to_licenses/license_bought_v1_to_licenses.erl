%%% @doc Projection: license_bought_v1 -> licenses ETS read model.
%%% Inserts a new license record.
-module(license_bought_v1_to_licenses).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, licenses).

interested_in() -> [<<"license_bought_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    LicenseId = gf(license_id, Data),
    License = #{
        license_id        => LicenseId,
        user_id           => gf(user_id, Data),
        plugin_id         => gf(plugin_id, Data),
        plugin_name       => gf(plugin_name, Data),
        oci_image         => gf(oci_image, Data),
        granted_at        => gf(granted_at, Data),
        revoked_at        => undefined,
        archived_at       => undefined,
        installed         => 0,
        installed_version => undefined,
        installed_at      => undefined,
        upgraded_at       => undefined,
        revoked           => 0,
        status            => 8,
        status_label      => <<"Licensed">>
    },
    {ok, RM2} = evoq_read_model:put(LicenseId, License, RM),
    {ok, State, RM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
