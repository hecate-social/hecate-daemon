%%% @doc API handler: GET/POST /api/launcher/entries
%%%
%%% GET  - Returns all launcher entries as a flat list.
%%% POST - Delegates to register_entry_api for entry registration.
%%% @end
-module(get_launcher_entries_api).

-export([init/2, routes/0]).

routes() -> [{"/api/launcher/entries", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        <<"POST">> -> register_entry_api:handle_post(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_launcher_store:list_entries() of
        {ok, Entries} ->
            hecate_api_utils:json_ok(#{entries => Entries}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
