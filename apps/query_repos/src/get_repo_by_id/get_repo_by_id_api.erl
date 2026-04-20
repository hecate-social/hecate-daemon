%%% @doc API handler: GET /api/repos/:id
%%%
%%% Returns metadata for a single repo.
%%% @end
-module(get_repo_by_id_api).

-export([init/2, routes/0]).

routes() -> [{"/api/repos/:id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    RepoId = cowboy_req:binding(id, Req0),
    case project_repos_store:get(RepoId) of
        {ok, Entry} ->
            hecate_api_utils:json_ok(Entry, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Repo not found">>, Req0)
    end.
