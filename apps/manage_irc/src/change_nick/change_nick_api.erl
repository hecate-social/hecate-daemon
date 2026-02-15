%%% @doc API handler: POST /api/irc/nick
%%%
%%% Changes the IRC nick for the current user's SSE stream session(s).
%%% The nick is ephemeral session state (not event-sourced) — like real IRC.
%%%
%%% Body: {"nick": "newname"}
%%%
%%% Broadcasts {change_nick, Nick} to all local SSE stream processes,
%%% which update their presence heartbeat display name accordingly.
%%% @end
-module(change_nick_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            Nick = hecate_api_utils:get_field(nick, Params),
            case Nick of
                undefined ->
                    hecate_api_utils:bad_request(<<"nick is required">>, Req1);
                <<>> ->
                    hecate_api_utils:bad_request(<<"nick cannot be empty">>, Req1);
                _ ->
                    Members = pg:get_members(pg, irc_stream),
                    lists:foreach(fun(Pid) -> Pid ! {change_nick, Nick} end, Members),
                    hecate_api_utils:json_ok(#{nick => Nick, changed => true}, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.
