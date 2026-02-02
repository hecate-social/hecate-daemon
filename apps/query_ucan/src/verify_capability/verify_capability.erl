%%% @doc Query: Verify a UCAN capability
%%% Checks if a specific capability is valid (active, not revoked, not expired).
-module(verify_capability).

-export([execute/1, execute/3]).

%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [execute/1]}).

%% @doc Verify a capability by its ID.
-spec execute(binary()) -> {ok, valid | invalid, map()} | {error, term()}.
execute(CapabilityId) ->
    Now = erlang:system_time(millisecond),
    Sql = io_lib:format(
        "SELECT capability_id, issuer, audience, resource, actions, "
        "       expires_at, granted_at, revoked, revoked_at "
        "FROM capabilities "
        "WHERE capability_id = '~s'",
        [escape_sql(CapabilityId)]
    ),

    case query_ucan_store:query(iolist_to_binary(Sql)) of
        {ok, [[CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt, Revoked, RevokedAt]]} ->
            Capability = #{
                capability_id => CapId,
                issuer => Issuer,
                audience => Audience,
                resource => Resource,
                actions => json:decode(Actions),
                expires_at => ExpiresAt,
                granted_at => GrantedAt,
                revoked => Revoked =:= 1,
                revoked_at => RevokedAt
            },
            Validity = check_validity(Revoked, ExpiresAt, Now),
            {ok, Validity, Capability};
        {ok, []} ->
            {ok, invalid, #{reason => not_found}};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Verify a capability for a specific action on a resource.
-spec execute(binary(), binary(), binary()) -> {ok, valid | invalid, map()} | {error, term()}.
execute(Audience, Resource, Action) ->
    Now = erlang:system_time(millisecond),
    Sql = io_lib:format(
        "SELECT capability_id, issuer, audience, resource, actions, "
        "       expires_at, granted_at, revoked, revoked_at "
        "FROM capabilities "
        "WHERE audience = '~s' AND resource = '~s' "
        "  AND revoked = 0 AND expires_at > ~B",
        [escape_sql(Audience), escape_sql(Resource), Now]
    ),

    case query_ucan_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            case find_matching_capability(Rows, Action) of
                {ok, Capability} ->
                    {ok, valid, Capability};
                not_found ->
                    {ok, invalid, #{reason => no_matching_capability}}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

check_validity(1, _ExpiresAt, _Now) ->
    invalid;
check_validity(_Revoked, ExpiresAt, Now) when ExpiresAt =< Now ->
    invalid;
check_validity(_Revoked, _ExpiresAt, _Now) ->
    valid.

find_matching_capability([], _Action) ->
    not_found;
find_matching_capability([[CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt, Revoked, RevokedAt] | Rest], Action) ->
    ActionsList = json:decode(Actions),
    case lists:member(Action, ActionsList) orelse lists:member(<<"*">>, ActionsList) of
        true ->
            {ok, #{
                capability_id => CapId,
                issuer => Issuer,
                audience => Audience,
                resource => Resource,
                actions => ActionsList,
                expires_at => ExpiresAt,
                granted_at => GrantedAt,
                revoked => Revoked =:= 1,
                revoked_at => RevokedAt
            }};
        false ->
            find_matching_capability(Rest, Action)
    end.

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
