%%% @doc Merged projection: realm membership lifecycle events -> ETS.
%%%
%%% Handles initiated, confirmed, and revoked events in a single
%%% projection to guarantee ordering.
%%% @end
-module(membership_lifecycle_to_memberships).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-include_lib("guide_realm_memberships/include/membership_status.hrl").

-define(TABLE, realm_memberships).

interested_in() ->
    [<<"realm_membership_initiated_v1">>,
     <<"realm_membership_confirmed_v1">>,
     <<"realm_membership_revoked_v1">>,
     <<"realm_shared_key_stored_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"realm_membership_initiated_v1">> -> project_initiated(Data, State, RM);
        <<"realm_membership_confirmed_v1">> -> project_confirmed(Data, State, RM);
        <<"realm_membership_revoked_v1">>   -> project_revoked(Data, State, RM);
        <<"realm_shared_key_stored_v1">>    -> project_key_stored(Data, State, RM);
        _                                   -> {ok, State, RM}
    end.

%% --- Initiated: create membership entry ---

project_initiated(Data, State, RM) ->
    MembershipId = gf(membership_id, Data),
    Status = ?MEMBERSHIP_INITIATED,
    Entry = #{
        membership_id   => MembershipId,
        realm_id        => undefined,
        realm_url       => gf(realm_url, Data),
        oauth_account   => undefined,
        oauth_provider  => undefined,
        status          => Status,
        status_label    => <<"Initiated">>,
        available_actions => [<<"confirm">>],
        initiated_at    => gf(initiated_at, Data),
        confirmed_at    => undefined,
        revoked_at      => undefined
    },
    {ok, RM2} = evoq_read_model:put(MembershipId, Entry, RM),
    {ok, State, RM2}.

%% --- Confirmed: update with OAuth details ---

project_confirmed(Data, State, RM) ->
    MembershipId = gf(membership_id, Data),
    case ets:lookup(?TABLE, MembershipId) of
        [{_, #{status := OldStatus} = Existing}] ->
            NewStatus = evoq_bit_flags:set(OldStatus, ?MEMBERSHIP_CONFIRMED),
            Updated = Existing#{
                realm_id          => gf(realm_id, Data),
                oauth_account     => gf(oauth_account, Data),
                oauth_provider    => gf(oauth_provider, Data),
                status            => NewStatus,
                status_label      => <<"Confirmed">>,
                available_actions => [<<"revoke">>],
                confirmed_at      => gf(confirmed_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(MembershipId, Updated, RM),
            hecate_web_events:broadcast(settings_changed, #{reason => realm_confirmed}),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Key stored: flip REALM_KEY_STORED bit, record version ---

project_key_stored(Data, State, RM) ->
    MembershipId = gf(membership_id, Data),
    case ets:lookup(?TABLE, MembershipId) of
        [{_, #{status := OldStatus} = Existing}] ->
            NewStatus = evoq_bit_flags:set(OldStatus, ?REALM_KEY_STORED),
            Updated = Existing#{
                status              => NewStatus,
                k_realm_version     => gf(k_realm_version, Data),
                k_realm_received_at => gf(received_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(MembershipId, Updated, RM),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Revoked: mark as revoked ---

project_revoked(Data, State, RM) ->
    MembershipId = gf(membership_id, Data),
    case ets:lookup(?TABLE, MembershipId) of
        [{_, #{status := OldStatus} = Existing}] ->
            NewStatus = evoq_bit_flags:set(OldStatus, ?MEMBERSHIP_REVOKED),
            Updated = Existing#{
                status            => NewStatus,
                status_label      => <<"Revoked">>,
                available_actions => [],
                revoked_at        => gf(revoked_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(MembershipId, Updated, RM),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Internal ---

get_event_type(#{event_type := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
