%%% @doc API handler: GET /api/repos/search?tag=...&realm=...
%%%
%%% Returns repos carrying the given tag. Optional `realm` restricts to
%%% a specific realm (useful for Martha persona discovery).
%%% @end
-module(search_repos_by_tag_api).

-export([init/2, routes/0]).

routes() -> [{"/api/repos/search", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Qs  = cowboy_req:parse_qs(Req0),
    Tag = proplists:get_value(<<"tag">>, Qs),
    handle_search(Tag, Qs, Req0).

handle_search(undefined, _Qs, Req0) ->
    hecate_api_utils:json_error(400, <<"Missing required param: tag">>, Req0);
handle_search(Tag, Qs, Req0) ->
    Realm = proplists:get_value(<<"realm">>, Qs),
    {ok, Entries} = case Realm of
        undefined -> project_repos_store:search_by_tag(Tag);
        _         -> project_repos_store:search_by_tag(Tag, Realm)
    end,
    hecate_api_utils:json_ok(#{repos => Entries}, Req0).
