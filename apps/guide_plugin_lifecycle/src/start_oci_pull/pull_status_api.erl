%%% @doc API handler: GET /api/plugins/:name/pull-status
%%%
%%% Returns the current pull progress for a plugin.
%%% Reads from the plugin_pull_progress ETS table.
%%% @end
-module(pull_status_api).

-export([init/2, routes/0]).

routes() -> [{"/api/plugins/:name/pull-status", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    PluginId = cowboy_req:binding(name, Req0),
    Response = case ets:lookup(plugin_pull_progress, PluginId) of
        [{_, #{status := complete}}] ->
            #{status => <<"ready">>, percent => 100};
        [{_, #{status := error, reason := Reason}}] ->
            #{status => <<"error">>, reason => iolist_to_binary(io_lib:format("~p", [Reason]))};
        [{_, #{status := Status} = Progress}] ->
            Percent = maps:get(percent, Progress, 0),
            Line = maps:get(line, Progress, <<>>),
            #{status => atom_to_binary(Status), percent => Percent, line => Line};
        [] ->
            query_status_from_read_model(PluginId)
    end,
    hecate_api_utils:json_ok(200, Response, Req0).

query_status_from_read_model(PluginId) ->
    case project_plugins_store:get(PluginId) of
        {ok, #{status := Status}} when is_integer(Status), Status band 64 =/= 0 ->
            #{status => <<"pulling">>, percent => 0};
        _ ->
            #{status => <<"idle">>}
    end.
