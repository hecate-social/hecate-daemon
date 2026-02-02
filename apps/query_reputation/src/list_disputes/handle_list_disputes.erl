-module(handle_list_disputes).

-export([handle/1]).

%% Suppress supertype warning (error type from esqlite3 is integer, spec uses term())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle list_disputes query - list disputes with optional filtering.
-spec handle(list_disputes_v1:list_disputes_v1()) -> {ok, [map()]} | {error, term()}.
handle(Query) ->
    #{
        agent_identity := Identity,
        status_filter := StatusFilter
    } = list_disputes_v1:to_map(Query),

    {ok, Conn} = application:get_env(query_reputation, db_conn),

    {SQL, Params} = build_query(Identity, StatusFilter),

    case esqlite3:q(Conn, SQL, Params) of
        Rows when is_list(Rows) ->
            Results = [row_to_dispute(R) || R <- Rows],
            {ok, Results};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

build_query(undefined, undefined) ->
    {<<"
        SELECT dispute_id, call_id, flagger_identity, reason, resolution,
               resolver_identity, flagged_at, resolved_at
        FROM disputes
        ORDER BY flagged_at DESC
    ">>, []};
build_query(undefined, <<"pending">>) ->
    {<<"
        SELECT dispute_id, call_id, flagger_identity, reason, resolution,
               resolver_identity, flagged_at, resolved_at
        FROM disputes
        WHERE resolution IS NULL
        ORDER BY flagged_at DESC
    ">>, []};
build_query(undefined, <<"resolved">>) ->
    {<<"
        SELECT dispute_id, call_id, flagger_identity, reason, resolution,
               resolver_identity, flagged_at, resolved_at
        FROM disputes
        WHERE resolution IS NOT NULL
        ORDER BY resolved_at DESC
    ">>, []};
build_query(Identity, undefined) ->
    {<<"
        SELECT d.dispute_id, d.call_id, d.flagger_identity, d.reason, d.resolution,
               d.resolver_identity, d.flagged_at, d.resolved_at
        FROM disputes d
        JOIN rpc_calls r ON d.call_id = r.call_id
        WHERE r.caller_identity = ? OR r.callee_identity = ?
        ORDER BY d.flagged_at DESC
    ">>, [Identity, Identity]};
build_query(Identity, Status) ->
    StatusCondition = case Status of
        <<"pending">> -> <<"d.resolution IS NULL">>;
        <<"resolved">> -> <<"d.resolution IS NOT NULL">>
    end,
    {<<"
        SELECT d.dispute_id, d.call_id, d.flagger_identity, d.reason, d.resolution,
               d.resolver_identity, d.flagged_at, d.resolved_at
        FROM disputes d
        JOIN rpc_calls r ON d.call_id = r.call_id
        WHERE (r.caller_identity = ? OR r.callee_identity = ?) AND ", StatusCondition/binary, "
        ORDER BY d.flagged_at DESC
    ">>, [Identity, Identity]}.

row_to_dispute([DisputeId, CallId, Flagger, Reason, Resolution, Resolver, FlaggedAt, ResolvedAt]) ->
    #{
        dispute_id => DisputeId,
        call_id => CallId,
        flagger_identity => Flagger,
        reason => Reason,
        resolution => Resolution,
        resolver_identity => Resolver,
        flagged_at => FlaggedAt,
        resolved_at => ResolvedAt
    }.
