%%% @doc API handler: GET /api/node/plugins
%%%
%%% Returns all installed (non-removed) plugins on this node.
%%% @end
-module(list_plugins_api).

-export([init/2, routes/0]).

-define(PLUGIN_COLUMNS, [
    plugin_id, name, oci_image, installed_version,
    license_id, installed_at, upgraded_at,
    status, status_label
]).

-define(SQL,
    "SELECT plugin_id, name, oci_image, installed_version, "
    "license_id, installed_at, upgraded_at, "
    "status, status_label "
    "FROM plugins WHERE (status & 2) = 0").

routes() -> [{"/api/node/plugins", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_plugins_store:query(?SQL) of
        {ok, Rows} ->
            Items = [row_to_map(R) || R <- Rows],
            hecate_api_utils:json_ok(#{items => Items}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

row_to_map(Row) when is_list(Row) ->
    maps:from_list(lists:zip(?PLUGIN_COLUMNS, Row));
row_to_map(Row) when is_tuple(Row) ->
    maps:from_list(lists:zip(?PLUGIN_COLUMNS, tuple_to_list(Row))).
