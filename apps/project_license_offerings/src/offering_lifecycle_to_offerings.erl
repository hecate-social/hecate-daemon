%%% @doc Projection: offering lifecycle events -> offerings ETS read model.
%%%
%%% Handles initiated, announced, published, amended, retracted, and archived
%%% events in a SINGLE projection to guarantee ordering. Without this,
%%% downstream projections can race ahead of the initiate projection
%%% — they look up the entry by offering_id, but it does not exist yet
%%% because the initiate projection has not run.
%%% @end
-module(offering_lifecycle_to_offerings).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-include_lib("guide_license_offering_lifecycle/include/offering_status.hrl").

-define(TABLE, offerings).

interested_in() ->
    [<<"offering_initiated_v1">>,
     <<"offering_announced_v1">>,
     <<"offering_published_v1">>,
     <<"offering_amended_v1">>,
     <<"offering_retracted_v1">>,
     <<"offering_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    EventType = get_event_type(Event),
    case EventType of
        <<"offering_initiated_v1">>  -> project_initiated(Data, State, RM);
        <<"offering_announced_v1">>  -> project_announced(Data, State, RM);
        <<"offering_published_v1">>  -> project_published(Data, State, RM);
        <<"offering_amended_v1">>    -> project_amended(Data, State, RM);
        <<"offering_retracted_v1">>  -> project_retracted(Data, State, RM);
        <<"offering_archived_v1">>   -> project_archived(Data, State, RM);
        _                            -> {ok, State, RM}
    end.

%% --- Initiated: create offerings entry ---

project_initiated(Data, State, RM) ->
    OfferingId = gf(offering_id, Data),
    Entry = #{
        plugin_id           => gf(plugin_id, Data),
        offering_id         => OfferingId,
        name                => gf(plugin_name, Data),
        description         => gf(description, Data),
        icon                => gf(icon, Data),
        group_name          => gf(group_name, Data),
        github_repo         => gf(github_repo, Data),
        oci_image           => gf(oci_image, Data),
        package_url         => gf(package_url, Data),
        plugin_type         => gf(plugin_type, Data),
        callback_module     => gf(callback_module, Data),
        selling_formula     => gf(selling_formula, Data),
        author_id           => gf(author_id, Data),
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
        author_signature    => gf(author_signature, Data),
        oci_image_verified  => gf(oci_image_verified, Data),
        oci_image_digest    => gf(oci_image_digest, Data),
        announced_at        => undefined,
        published_at        => undefined,
        cataloged_at        => gf(initiated_at, Data),
        refreshed_at        => undefined,
        status              => ?OFF_INITIATED,
        status_label        => <<"Initiated">>,
        retracted           => 0
    },
    {ok, RM2} = evoq_read_model:put(OfferingId, Entry, RM),
    {ok, State, RM2}.

%% --- Announced: set announced flag ---

project_announced(Data, State, RM) ->
    OfferingId = gf(offering_id, Data),
    case evoq_read_model:get(OfferingId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                announced_at => gf(announced_at, Data),
                status       => evoq_bit_flags:set(maps:get(status, Existing), ?OFF_ANNOUNCED),
                status_label => <<"Announced">>
            },
            {ok, RM2} = evoq_read_model:put(OfferingId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Published: set published flag ---

project_published(Data, State, RM) ->
    OfferingId = gf(offering_id, Data),
    case evoq_read_model:get(OfferingId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                published_at => gf(published_at, Data),
                status       => evoq_bit_flags:set(maps:get(status, Existing), ?OFF_PUBLISHED),
                status_label => <<"Published">>
            },
            {ok, RM2} = evoq_read_model:put(OfferingId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Amended: update non-undefined fields ---

project_amended(Data, State, RM) ->
    OfferingId = gf(offering_id, Data),
    case evoq_read_model:get(OfferingId, RM) of
        {ok, Existing} ->
            Updated = apply_amendments(Existing, Data),
            {ok, RM2} = evoq_read_model:put(OfferingId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

apply_amendments(Entry, Data) ->
    Fields = [
        {plugin_name, name}, {description, description}, {icon, icon},
        {group_name, group_name}, {github_repo, github_repo}, {oci_image, oci_image},
        {package_url, package_url},
        {plugin_type, plugin_type}, {callback_module, callback_module},
        {org, org}, {version, version}, {manifest_tag, manifest_tag},
        {tags, tags}, {homepage, homepage},
        {min_daemon_version, min_daemon_version},
        {publisher_identity, publisher_identity},
        {manifest_url, manifest_url}, {manifest_checksum, manifest_checksum},
        {author_signature, author_signature},
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

%% --- Retracted: reset to retracted state ---

project_retracted(Data, State, RM) ->
    OfferingId = gf(offering_id, Data),
    case evoq_read_model:get(OfferingId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                status       => ?OFF_INITIATED,
                retracted    => 1,
                status_label => <<"Retracted">>,
                announced_at => undefined,
                published_at => undefined
            },
            {ok, RM2} = evoq_read_model:put(OfferingId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Archived: set archived flag ---

project_archived(Data, State, RM) ->
    OfferingId = gf(offering_id, Data),
    case evoq_read_model:get(OfferingId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                status       => evoq_bit_flags:set(maps:get(status, Existing), ?OFF_ARCHIVED),
                status_label => <<"Archived">>,
                archived_at  => gf(archived_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(OfferingId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

get_event_type(#{event_type := T}) -> T;
get_event_type(#{<<"event_type">> := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
