%%% @doc GET /api/plugins/loaded — list in-VM loaded plugins.
-module(get_loaded_plugins_api).

-export([routes/0]).
-export([init/2]).

routes() ->
    [{"/api/plugins/loaded", ?MODULE, []}].

init(Req0, State) ->
    Plugins = hecate_plugin_loader:loaded_plugins(),
    Req = hecate_api_utils:json_ok(Req0, #{plugins => Plugins}),
    {ok, Req, State}.
