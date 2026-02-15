%%% @doc API handler: POST /api/irc/channels/:channel_id/close
%%% Closes an IRC channel.
-module(close_channel_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ChannelId = cowboy_req:binding(channel_id, Req0),
    ClosedBy = case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, _Req1} -> hecate_api_utils:get_field(closed_by, Params);
        {error, invalid_json, _Req1} -> undefined
    end,
    case close_channel_v1:new(#{channel_id => ChannelId, closed_by => ClosedBy}) of
        {ok, Cmd} ->
            case maybe_close_channel:dispatch(Cmd) of
                {ok, _Version, _EventMaps} ->
                    hecate_api_utils:json_ok(#{channel_id => ChannelId, closed => true}, Req0);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req0)
    end.
