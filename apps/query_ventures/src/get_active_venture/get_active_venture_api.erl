%%% @doc API handler: GET /api/venture
%%%
%%% Get the current/active venture (first from list).
%%% @end
-module(get_active_venture_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case get_ventures_page:execute(#{limit => 1}) of
        {ok, [Venture | _]} ->
            hecate_api_utils:json_ok(#{venture => Venture}, Req0);
        {ok, []} ->
            hecate_api_utils:json_ok(#{venture => null}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
