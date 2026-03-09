%%% @doc API handler: GET /api/appstore/offerings/author
%%%
%%% Returns all offering entries for the authenticated author,
%%% regardless of status (draft, published, suspended).
%%% Requires X-Hecate-User-Id header.
%%% @end
-module(get_author_listings_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/offerings/author", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            hecate_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        AuthorId ->
            case project_license_offerings_store:get_author_listings(AuthorId) of
                {ok, Items} ->
                    hecate_api_utils:json_ok(#{items => Items}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.
