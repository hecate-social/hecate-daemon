%%% @doc API handler: GET /api/repos?owner_did=...
%%%
%%% Lists repos owned by a given DID. Omit `owner_did` to list all.
%%% Optional `realm` filter also supported.
%%% @end
-module(list_repos_by_owner_api).

-export([init/2, routes/0]).

routes() -> [{"/api/repos", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Qs = cowboy_req:parse_qs(Req0),
    Entries = filter(Qs),
    hecate_api_utils:json_ok(#{repos => Entries}, Req0).

filter(Qs) ->
    Owner = proplists:get_value(<<"owner_did">>, Qs),
    Realm = proplists:get_value(<<"realm">>, Qs),
    {ok, Base} = case {Owner, Realm} of
        {undefined, undefined} -> project_repos_store:list();
        {_, undefined}         -> project_repos_store:list_by_owner(Owner);
        {undefined, _}         -> project_repos_store:list_by_realm(Realm);
        {_, _} ->
            {ok, ByOwner} = project_repos_store:list_by_owner(Owner),
            {ok, [E || #{realm := R} = E <- ByOwner, R =:= Realm]}
    end,
    Base.
