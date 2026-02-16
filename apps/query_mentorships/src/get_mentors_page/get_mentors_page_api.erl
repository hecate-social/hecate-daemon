-module(get_mentors_page_api).
-export([init/2, routes/0]).

routes() -> [{"/api/mentors/profiles", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = case proplists:get_value(<<"domain">>, QS) of
        undefined -> #{};
        Domain -> #{domain => Domain}
    end,
    case get_mentors_page:execute(Filters) of
        {ok, Mentors} ->
            hecate_api_utils:json_ok(#{mentors => Mentors}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
