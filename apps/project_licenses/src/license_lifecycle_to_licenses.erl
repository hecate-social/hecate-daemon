%%% @doc Projection: consumer license lifecycle events -> licenses ETS read model.
%%%
%%% Merged projection handling ALL consumer license events in a SINGLE
%%% gen_server to guarantee ordering. Keyed by license_id.
%%% @end
-module(license_lifecycle_to_licenses).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).
-export([available_actions/1]).

-include_lib("guide_license_lifecycle/include/license_status.hrl").

-define(TABLE, licenses).

interested_in() ->
    [<<"license_initiated_v1">>,
     <<"offering_terms_accepted_v1">>,
     <<"offering_terms_rejected_v1">>,
     <<"license_bought_v1">>,
     <<"license_abandoned_v1">>,
     <<"license_granted_v1">>,
     <<"license_expired_v1">>,
     <<"license_renewed_v1">>,
     <<"license_revoked_v1">>,
     <<"license_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    EventType = get_event_type(Event),
    case EventType of
        <<"license_initiated_v1">>          -> project_initiated(Data, State, RM);
        <<"offering_terms_accepted_v1">>    -> project_accepted(Data, State, RM);
        <<"offering_terms_rejected_v1">>    -> project_terminal(Data, <<"Rejected">>, State, RM);
        <<"license_bought_v1">>             -> project_bought(Data, State, RM);
        <<"license_abandoned_v1">>          -> project_terminal(Data, <<"Abandoned">>, State, RM);
        <<"license_granted_v1">>            -> project_granted(Data, State, RM);
        <<"license_expired_v1">>            -> project_expired(Data, State, RM);
        <<"license_renewed_v1">>            -> project_renewed(Data, State, RM);
        <<"license_revoked_v1">>            -> project_revoked(Data, State, RM);
        <<"license_archived_v1">>           -> project_archived(Data, State, RM);
        _                                   -> {ok, State, RM}
    end.

%% --- Initiated: full birth with offering snapshot ---

project_initiated(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    Entry = #{
        license_id         => LicenseId,
        consumer_id        => gf(consumer_id, Data),
        offering_id        => gf(offering_id, Data),
        plugin_id          => gf(plugin_id, Data),
        plugin_name        => gf(plugin_name, Data),
        description        => gf(description, Data),
        icon               => gf(icon, Data),
        group_name         => gf(group_name, Data),
        group_icon         => gf(group_icon, Data),
        github_repo        => gf(github_repo, Data),
        oci_image          => gf(oci_image, Data),
        selling_formula    => gf(selling_formula, Data),
        author_id          => gf(author_id, Data),
        license_type       => gf(license_type, Data),
        fee_cents          => gf(fee_cents, Data),
        fee_currency       => gf(fee_currency, Data),
        duration_days      => gf(duration_days, Data),
        node_limit         => gf(node_limit, Data),
        org                => gf(org, Data),
        version            => gf(version, Data),
        manifest_tag       => gf(manifest_tag, Data),
        tags               => gf(tags, Data),
        homepage           => gf(homepage, Data),
        min_daemon_version => gf(min_daemon_version, Data),
        publisher_identity => gf(publisher_identity, Data),
        manifest_url       => gf(manifest_url, Data),
        manifest_checksum  => gf(manifest_checksum, Data),
        author_signature   => gf(author_signature, Data),
        oci_image_verified => gf(oci_image_verified, Data),
        oci_image_digest   => gf(oci_image_digest, Data),
        status             => ?LIC_INITIATED,
        status_label       => <<"Initiated">>,
        available_actions  => available_actions(?LIC_INITIATED),
        initiated_at       => gf(initiated_at, Data)
    },
    {ok, RM2} = evoq_read_model:put(LicenseId, Entry, RM),
    {ok, State, RM2}.

%% --- Accepted: lightweight consent, just update status ---

project_accepted(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            NewStatus = evoq_bit_flags:set(maps:get(status, Existing), ?LIC_ACCEPTED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Accepted">>,
                available_actions => available_actions(NewStatus),
                accepted_at       => gf(accepted_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Bought ---

project_bought(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            NewStatus = evoq_bit_flags:set(maps:get(status, Existing), ?LIC_BOUGHT),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Bought">>,
                available_actions => available_actions(NewStatus),
                bought_at         => gf(bought_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Granted ---

project_granted(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            NewStatus = evoq_bit_flags:set(maps:get(status, Existing), ?LIC_GRANTED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Granted">>,
                available_actions => available_actions(NewStatus),
                granted_at        => gf(granted_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Expired ---

project_expired(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            NewStatus = evoq_bit_flags:set(maps:get(status, Existing), ?LIC_EXPIRED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Expired">>,
                available_actions => available_actions(NewStatus),
                expired_at        => gf(expired_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Renewed ---

project_renewed(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            Unset = evoq_bit_flags:unset(maps:get(status, Existing), ?LIC_EXPIRED),
            NewStatus = evoq_bit_flags:set(Unset, ?LIC_GRANTED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Granted">>,
                available_actions => available_actions(NewStatus),
                renewed_at        => gf(renewed_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Revoked ---

project_revoked(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            NewStatus = evoq_bit_flags:set(maps:get(status, Existing), ?LIC_REVOKED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Revoked">>,
                available_actions => available_actions(NewStatus),
                revoked_at        => gf(revoked_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Archived ---

project_archived(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            NewStatus = evoq_bit_flags:set(maps:get(status, Existing), ?LIC_ARCHIVED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Archived">>,
                available_actions => available_actions(NewStatus),
                archived_at       => gf(archived_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Terminal (rejected/abandoned) — set archived flag ---

project_terminal(Data, Label, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            NewStatus = evoq_bit_flags:set(maps:get(status, Existing), ?LIC_ARCHIVED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => Label,
                available_actions => available_actions(NewStatus)
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Available Actions ---

available_actions(Status) when is_integer(Status) ->
    case true of
        _ when Status band ?LIC_ARCHIVED =/= 0 -> [];
        _ when Status band ?LIC_REVOKED  =/= 0 -> [<<"archive">>];
        _ when Status band ?LIC_EXPIRED  =/= 0 -> [<<"renew">>, <<"archive">>];
        _ when Status band ?LIC_GRANTED  =/= 0 -> [<<"revoke">>, <<"archive">>];
        _ when Status band ?LIC_BOUGHT   =/= 0 -> [];
        _ when Status band ?LIC_ACCEPTED =/= 0 -> [<<"buy">>, <<"abandon">>, <<"archive">>];
        _ when Status band ?LIC_INITIATED =/= 0 -> [<<"accept">>, <<"reject">>, <<"archive">>];
        _ -> []
    end.

%% --- Internal ---

get_event_type(#{event_type := T}) -> T;
get_event_type(#{<<"event_type">> := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
