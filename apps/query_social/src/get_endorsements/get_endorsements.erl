%%% @doc Query handler: get endorsements for a capability or by an endorser.
-module(get_endorsements).

-export([by_capability/1, by_endorser/1, active_by_capability/1, by_capability_owner/1]).

%% @doc Get all endorsements for a capability (including revoked).
-spec by_capability(binary()) -> {ok, [map()]} | {error, term()}.
by_capability(CapabilityMRI) ->
    Sql = io_lib:format(
        "SELECT endorser_identity, capability_mri, comment, endorsed_at, revoked_at "
        "FROM endorsements WHERE capability_mri = '~s' "
        "ORDER BY endorsed_at DESC",
        [escape_sql(CapabilityMRI)]
    ),
    execute_query(iolist_to_binary(Sql)).

%% @doc Get all active endorsements for a capability.
-spec active_by_capability(binary()) -> {ok, [map()]} | {error, term()}.
active_by_capability(CapabilityMRI) ->
    Sql = io_lib:format(
        "SELECT endorser_identity, capability_mri, comment, endorsed_at "
        "FROM endorsements WHERE capability_mri = '~s' AND revoked_at IS NULL "
        "ORDER BY endorsed_at DESC",
        [escape_sql(CapabilityMRI)]
    ),
    execute_query(iolist_to_binary(Sql)).

%% @doc Get endorsements received by an agent (on capabilities they own).
%% This queries capabilities owned by the agent, then finds endorsements for those.
-spec by_capability_owner(binary()) -> {ok, [map()]} | {error, term()}.
by_capability_owner(OwnerIdentity) ->
    %% First get capabilities owned by this agent
    case query_capabilities_store:query(
        "SELECT mri FROM capabilities WHERE agent_id = ?",
        [OwnerIdentity]
    ) of
        {ok, []} ->
            {ok, []};
        {ok, Rows} ->
            MRIs = [M || [M] <- Rows],
            get_endorsements_for_mris(MRIs);
        {error, Reason} ->
            {error, Reason}
    end.

get_endorsements_for_mris([]) ->
    {ok, []};
get_endorsements_for_mris(MRIs) ->
    %% Build IN clause for multiple MRIs
    Placeholders = string:join(lists:duplicate(length(MRIs), "?"), ","),
    Sql = iolist_to_binary([
        "SELECT endorser_identity, capability_mri, comment, endorsed_at, revoked_at ",
        "FROM endorsements WHERE capability_mri IN (", Placeholders, ") ",
        "ORDER BY endorsed_at DESC"
    ]),
    case query_social_store:query(Sql, MRIs) of
        {ok, Rows} ->
            Results = [row_to_map(R) || R <- Rows],
            {ok, Results};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Get all endorsements given by an agent.
-spec by_endorser(binary()) -> {ok, [map()]} | {error, term()}.
by_endorser(EndorserIdentity) ->
    Sql = io_lib:format(
        "SELECT endorser_identity, capability_mri, comment, endorsed_at, revoked_at "
        "FROM endorsements WHERE endorser_identity = '~s' "
        "ORDER BY endorsed_at DESC",
        [escape_sql(EndorserIdentity)]
    ),
    execute_query(iolist_to_binary(Sql)).

%% Internal functions

execute_query(Sql) ->
    case query_social_store:query(Sql) of
        {ok, Rows} ->
            Results = [row_to_map(R) || R <- Rows],
            {ok, Results};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map([Endorser, MRI, Comment, EndorsedAt, RevokedAt]) ->
    #{
        endorser_identity => Endorser,
        capability_mri => MRI,
        comment => Comment,
        endorsed_at => EndorsedAt,
        revoked_at => RevokedAt
    };
row_to_map([Endorser, MRI, Comment, EndorsedAt]) ->
    #{
        endorser_identity => Endorser,
        capability_mri => MRI,
        comment => Comment,
        endorsed_at => EndorsedAt
    }.

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
