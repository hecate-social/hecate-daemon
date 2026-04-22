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
     <<"realm_membership_ended_v1">>,
     <<"realm_membership_resigned_v1">>,
     <<"realm_shared_key_stored_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"realm_membership_initiated_v1">> -> project_initiated(Data, State, RM);
        <<"realm_membership_confirmed_v1">> -> project_confirmed(Data, State, RM);
        %% Old event kept for historical streams — upcast to ended.
        <<"realm_membership_revoked_v1">>   -> project_ended(upcast_revoked(Data), State, RM);
        <<"realm_membership_ended_v1">>     -> project_ended(Data, State, RM);
        <<"realm_membership_resigned_v1">>  -> project_resigned(Data, State, RM);
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

%% --- Ended: terminal transition (revoked or resigned) ---

project_ended(Data, State, RM) ->
    MembershipId = gf(membership_id, Data),
    case ets:lookup(?TABLE, MembershipId) of
        [{_, #{status := OldStatus} = Existing}] ->
            Reason = normalize_reason(gf(reason, Data, revoked)),
            NewStatus0 = evoq_bit_flags:set(OldStatus, ?MEMBERSHIP_ENDED),
            NewStatus = case Reason of
                revoked -> evoq_bit_flags:set(NewStatus0, ?MEMBERSHIP_REVOKED);
                _       -> NewStatus0
            end,
            Updated = Existing#{
                status            => NewStatus,
                status_label      => ended_label(Reason),
                available_actions => [],
                ended_at          => gf(ended_at, Data),
                end_reason        => Reason,
                ended_by          => gf(ended_by, Data),
                revoked_at        => revoked_timestamp(Existing, Reason, Data)
            },
            {ok, RM2} = evoq_read_model:put(MembershipId, Updated, RM),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Resigned: stamp resigned_at; the concurrent ended event drives
%% the terminal transition. Separate fold so both orderings stay safe.
project_resigned(Data, State, RM) ->
    MembershipId = gf(membership_id, Data),
    case ets:lookup(?TABLE, MembershipId) of
        [{_, #{status := OldStatus} = Existing}] ->
            NewStatus = evoq_bit_flags:set(OldStatus, ?MEMBERSHIP_RESIGNED),
            Updated = Existing#{
                status      => NewStatus,
                resigned_at => gf(resigned_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(MembershipId, Updated, RM),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Historical upcaster: old revoked events lacked `reason` + `ended_at`.

upcast_revoked(Data) ->
    At = gf(revoked_at, Data),
    Data#{
        ended_at   => At,
        reason     => revoked
    }.

normalize_reason(A) when is_atom(A) -> A;
normalize_reason(B) when is_binary(B) ->
    try binary_to_existing_atom(B, utf8)
    catch _:_ -> revoked
    end;
normalize_reason(_) -> revoked.

ended_label(revoked)  -> <<"Revoked">>;
ended_label(resigned) -> <<"Resigned">>;
ended_label(banned)   -> <<"Banned">>;
ended_label(_)        -> <<"Ended">>.

revoked_timestamp(#{revoked_at := At}, _Reason, _Data) when At =/= undefined -> At;
revoked_timestamp(_Existing, revoked, Data) -> gf(ended_at, Data);
revoked_timestamp(_Existing, _Other,  _Data) -> undefined.

%% --- Internal ---

get_event_type(#{event_type := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
gf(Key, Data, Default) -> hecate_api_utils:get_field(Key, Data, Default).
