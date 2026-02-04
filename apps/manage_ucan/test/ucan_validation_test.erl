%%% @doc Tests for UCAN command validation
-module(ucan_validation_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Grant capability validation
%% ===================================================================

valid_grant_test() ->
    Cmd = grant_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        <<"mri:agent:io.macula/audience">>,
        <<"mri:capability:io.macula/weather">>,
        [<<"read">>, <<"execute">>],
        erlang:system_time(millisecond) + 3600000,
        erlang:system_time(millisecond)
    ),
    {ok, [_Event]} = maybe_grant_capability:handle(Cmd).

grant_rejects_empty_capability_id_test() ->
    Cmd = grant_capability_v1:new(
        <<>>,
        <<"mri:agent:io.macula/issuer">>,
        <<"mri:agent:io.macula/audience">>,
        <<"mri:capability:io.macula/weather">>,
        [<<"read">>],
        erlang:system_time(millisecond) + 3600000,
        erlang:system_time(millisecond)
    ),
    ?assertEqual({error, capability_id_required}, maybe_grant_capability:handle(Cmd)).

grant_rejects_invalid_issuer_mri_test() ->
    Cmd = grant_capability_v1:new(
        <<"cap-123">>,
        <<"not-a-valid-mri">>,
        <<"mri:agent:io.macula/audience">>,
        <<"mri:capability:io.macula/weather">>,
        [<<"read">>],
        erlang:system_time(millisecond) + 3600000,
        erlang:system_time(millisecond)
    ),
    ?assertEqual({error, invalid_issuer_mri}, maybe_grant_capability:handle(Cmd)).

grant_rejects_invalid_audience_mri_test() ->
    Cmd = grant_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        <<"just-a-name">>,
        <<"mri:capability:io.macula/weather">>,
        [<<"read">>],
        erlang:system_time(millisecond) + 3600000,
        erlang:system_time(millisecond)
    ),
    ?assertEqual({error, invalid_audience_mri}, maybe_grant_capability:handle(Cmd)).

grant_rejects_invalid_resource_uri_test() ->
    Cmd = grant_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        <<"mri:agent:io.macula/audience">>,
        <<"not-a-uri">>,
        [<<"read">>],
        erlang:system_time(millisecond) + 3600000,
        erlang:system_time(millisecond)
    ),
    ?assertEqual({error, invalid_resource_uri}, maybe_grant_capability:handle(Cmd)).

grant_rejects_unknown_actions_test() ->
    Cmd = grant_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        <<"mri:agent:io.macula/audience">>,
        <<"mri:capability:io.macula/weather">>,
        [<<"read">>, <<"destroy">>],
        erlang:system_time(millisecond) + 3600000,
        erlang:system_time(millisecond)
    ),
    {error, {unknown_actions, [<<"destroy">>]}} = maybe_grant_capability:handle(Cmd).

grant_rejects_expired_token_test() ->
    Now = erlang:system_time(millisecond),
    Cmd = grant_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        <<"mri:agent:io.macula/audience">>,
        <<"mri:capability:io.macula/weather">>,
        [<<"read">>],
        Now - 1000,  %% Already expired
        Now
    ),
    ?assertEqual({error, invalid_expiration}, maybe_grant_capability:handle(Cmd)).

grant_accepts_did_identities_test() ->
    Cmd = grant_capability_v1:new(
        <<"cap-456">>,
        <<"did:key:z6Mk...">>,
        <<"did:key:z6Mn...">>,
        <<"mri:capability:io.macula/calc">>,
        [<<"execute">>],
        erlang:system_time(millisecond) + 3600000,
        erlang:system_time(millisecond)
    ),
    {ok, [_Event]} = maybe_grant_capability:handle(Cmd).

%% ===================================================================
%% Revoke capability validation
%% ===================================================================

valid_revoke_test() ->
    Cmd = revoke_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        erlang:system_time(millisecond)
    ),
    {ok, [_Event]} = maybe_revoke_capability:handle(Cmd).

revoke_rejects_empty_capability_id_test() ->
    Cmd = revoke_capability_v1:new(
        <<>>,
        <<"mri:agent:io.macula/issuer">>,
        erlang:system_time(millisecond)
    ),
    ?assertEqual({error, capability_id_required}, maybe_revoke_capability:handle(Cmd)).

revoke_rejects_invalid_revoker_mri_test() ->
    Cmd = revoke_capability_v1:new(
        <<"cap-123">>,
        <<"not-a-valid-mri">>,
        erlang:system_time(millisecond)
    ),
    ?assertEqual({error, invalid_revoker_mri}, maybe_revoke_capability:handle(Cmd)).

%% ===================================================================
%% Aggregate authority check
%% ===================================================================

aggregate_rejects_unauthorized_revoke_test() ->
    %% First, build a state with a grant from issuer-a
    State0 = ucan_aggregate:initial_state(),
    GrantEvent = #{
        event_type => <<"capability_granted_v1">>,
        capability_id => <<"cap-123">>,
        issuer => <<"mri:agent:io.macula/issuer-a">>,
        audience => <<"mri:agent:io.macula/audience">>,
        resource => <<"mri:capability:io.macula/weather">>,
        actions => [<<"read">>],
        expires_at => erlang:system_time(millisecond) + 3600000,
        granted_at => erlang:system_time(millisecond)
    },
    State1 = ucan_aggregate:apply_event(GrantEvent, State0),

    %% Try to revoke as a different agent
    RevokePayload = #{
        command_type => revoke_capability,
        capability_id => <<"cap-123">>,
        revoker => <<"mri:agent:io.macula/attacker">>,
        revoked_at => erlang:system_time(millisecond)
    },
    ?assertEqual({error, not_authorized_to_revoke},
                 ucan_aggregate:execute(RevokePayload, State1)).

aggregate_allows_issuer_revoke_test() ->
    State0 = ucan_aggregate:initial_state(),
    GrantEvent = #{
        event_type => <<"capability_granted_v1">>,
        capability_id => <<"cap-456">>,
        issuer => <<"mri:agent:io.macula/issuer-a">>,
        audience => <<"mri:agent:io.macula/audience">>,
        resource => <<"mri:capability:io.macula/calc">>,
        actions => [<<"execute">>],
        expires_at => erlang:system_time(millisecond) + 3600000,
        granted_at => erlang:system_time(millisecond)
    },
    State1 = ucan_aggregate:apply_event(GrantEvent, State0),

    %% Revoke as the original issuer
    RevokePayload = #{
        command_type => revoke_capability,
        capability_id => <<"cap-456">>,
        revoker => <<"mri:agent:io.macula/issuer-a">>,
        revoked_at => erlang:system_time(millisecond)
    },
    {ok, _Events} = ucan_aggregate:execute(RevokePayload, State1).
