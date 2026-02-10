%%% @doc API handler: GET /api/torch
%%%
%%% Get the current/active torch (first from list).
%%% @end
-module(get_active_torch_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case get_torches_page:execute(#{limit => 1}) of
        {ok, [Torch | _]} ->
            hecate_api_utils:json_ok(#{torch => Torch}, Req0);
        {ok, []} ->
            hecate_api_utils:json_ok(#{torch => null}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
