%%% @doc API handler: GET /api/appstore/licenses
%%%
%%% Returns all active (non-archived) licenses for the current user.
%%% @end
-module(get_licenses_page_api).

-export([init/2, routes/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

-define(LICENSE_COLUMNS, [
    license_id, user_id, plugin_id, plugin_name,
    installed, installed_version, oci_image,
    granted_at, installed_at, upgraded_at, revoked, revoked_at
]).

-define(SQL,
    "SELECT license_id, user_id, plugin_id, plugin_name, "
    "installed, installed_version, oci_image, "
    "granted_at, installed_at, upgraded_at, revoked, revoked_at "
    "FROM licenses WHERE user_id = ?1 AND (status & 32) = 0").

routes() -> [{"/api/appstore/licenses", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            hecate_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        UserId ->
            case project_licenses_store:query(?SQL, [UserId]) of
                {ok, Rows} ->
                    Items = [row_to_map(R) || R <- Rows],
                    hecate_api_utils:json_ok(#{items => Items}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.

row_to_map(Row) when is_list(Row) ->
    maps:from_list(lists:zip(?LICENSE_COLUMNS, Row));
row_to_map(Row) when is_tuple(Row) ->
    maps:from_list(lists:zip(?LICENSE_COLUMNS, tuple_to_list(Row))).
