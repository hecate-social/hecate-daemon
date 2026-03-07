%%% @doc Projection: license_initiated_v1 -> catalog ETS read model.
%%% Inserts a new catalog entry when a seller initiates a license.
-module(license_initiated_v1_to_catalog).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, catalog).

interested_in() -> [<<"license_initiated_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    PluginId = gf(plugin_id, Data),
    Entry = #{
        plugin_id           => PluginId,
        license_id          => gf(license_id, Data),
        name                => gf(plugin_name, Data),
        description         => gf(description, Data),
        icon                => gf(icon, Data),
        github_repo         => gf(github_repo, Data),
        oci_image           => gf(oci_image, Data),
        selling_formula     => gf(selling_formula, Data),
        seller_id           => gf(seller_id, Data),
        license_type        => gf(license_type, Data),
        fee_cents           => gf(fee_cents, Data),
        fee_currency        => gf(fee_currency, Data),
        duration_days       => gf(duration_days, Data),
        node_limit          => gf(node_limit, Data),
        org                 => gf(org, Data),
        version             => gf(version, Data),
        manifest_tag        => gf(manifest_tag, Data),
        tags                => gf(tags, Data),
        homepage            => gf(homepage, Data),
        min_daemon_version  => gf(min_daemon_version, Data),
        publisher_identity  => gf(publisher_identity, Data),
        manifest_url        => gf(manifest_url, Data),
        manifest_checksum   => gf(manifest_checksum, Data),
        seller_signature    => gf(seller_signature, Data),
        oci_image_verified  => gf(oci_image_verified, Data),
        oci_image_digest    => gf(oci_image_digest, Data),
        announced_at        => undefined,
        published_at        => undefined,
        cataloged_at        => gf(initiated_at, Data),
        refreshed_at        => undefined,
        status              => 1,
        status_label        => <<"Initiated">>,
        retracted           => 0
    },
    {ok, RM2} = evoq_read_model:put(PluginId, Entry, RM),
    {ok, State, RM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
