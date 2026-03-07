%%% @doc Projection: license_amended_v1 -> catalog ETS read model.
%%% Updates only the non-undefined fields in the catalog entry.
-module(license_amended_v1_to_catalog).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, catalog).

interested_in() -> [<<"license_amended_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    LicenseId = gf(license_id, Data),
    case find_by_license_id(LicenseId) of
        {ok, PluginId, Existing} ->
            Updated = apply_amendments(Existing, Data),
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        not_found ->
            {ok, State, RM}
    end.

apply_amendments(Entry, Data) ->
    Fields = [
        {plugin_name, name}, {description, description}, {icon, icon},
        {github_repo, github_repo}, {oci_image, oci_image},
        {org, org}, {version, version}, {manifest_tag, manifest_tag},
        {tags, tags}, {homepage, homepage},
        {min_daemon_version, min_daemon_version},
        {publisher_identity, publisher_identity},
        {manifest_url, manifest_url}, {manifest_checksum, manifest_checksum},
        {seller_signature, seller_signature},
        {oci_image_verified, oci_image_verified},
        {oci_image_digest, oci_image_digest},
        {selling_formula, selling_formula}, {license_type, license_type},
        {fee_cents, fee_cents}, {fee_currency, fee_currency},
        {duration_days, duration_days}, {node_limit, node_limit}
    ],
    lists:foldl(fun({EventKey, MapKey}, Acc) ->
        case gf(EventKey, Data) of
            undefined -> Acc;
            Value -> Acc#{MapKey => Value}
        end
    end, Entry, Fields).

find_by_license_id(LicenseId) ->
    All = ets:tab2list(catalog),
    case [E || {_K, #{license_id := LId} = E} <- All, LId =:= LicenseId] of
        [#{plugin_id := PId} = Entry | _] -> {ok, PId, Entry};
        [] -> not_found
    end.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
