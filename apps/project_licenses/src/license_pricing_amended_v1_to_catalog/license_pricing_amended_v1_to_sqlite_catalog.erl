%%% @doc Projection: license_pricing_amended_v1 -> plugin_catalog table.
%%% Updates only the non-null pricing fields in the catalog row.
-module(license_pricing_amended_v1_to_sqlite_catalog).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(EventMap) ->
    LicenseId = hecate_api_utils:get_field(license_id, EventMap),
    {SetClauses, Params} = build_set_clauses(EventMap),
    case SetClauses of
        [] ->
            ok;
        _ ->
            SetStr = lists:join(", ", SetClauses),
            Sql = io_lib:format(
                "UPDATE plugin_catalog SET ~s WHERE license_id = ?1",
                [SetStr]
            ),
            project_licenses_store:execute(lists:flatten(Sql), [LicenseId | Params])
    end.

%% Internal

build_set_clauses(EventMap) ->
    Fields = [
        {selling_formula, "selling_formula"},
        {license_type, "license_type"},
        {fee_cents, "fee_cents"},
        {fee_currency, "fee_currency"},
        {duration_days, "duration_days"},
        {node_limit, "node_limit"}
    ],
    {Clauses, Params, _Idx} = lists:foldl(
        fun({Key, ColName}, {CAcc, PAcc, Idx}) ->
            case hecate_api_utils:get_field(Key, EventMap) of
                undefined ->
                    {CAcc, PAcc, Idx};
                Value ->
                    Placeholder = io_lib:format("?~b", [Idx]),
                    Clause = io_lib:format("~s = ~s", [ColName, Placeholder]),
                    {CAcc ++ [lists:flatten(Clause)], PAcc ++ [Value], Idx + 1}
            end
        end,
        {[], [], 2},
        Fields
    ),
    {Clauses, Params}.
