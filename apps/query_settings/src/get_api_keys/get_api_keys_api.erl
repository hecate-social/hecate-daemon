%%% @doc API handler: GET /api/settings/api-keys
%%%
%%% Returns api keys with keys REDACTED (only provider, label, configured_at).
-module(get_api_keys_api).
-export([init/2, routes/0]).

routes() -> [{"/api/settings/api-keys", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Sql = "SELECT provider, label, configured_at FROM api_keys ORDER BY provider",
    case project_settings_store:query(Sql) of
        {ok, Rows} ->
            Keys = [#{
                provider => Provider,
                label => Label,
                configured_at => ConfiguredAt
            } || [Provider, Label, ConfiguredAt] <- Rows],
            hecate_api_utils:json_ok(#{api_keys => Keys}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
