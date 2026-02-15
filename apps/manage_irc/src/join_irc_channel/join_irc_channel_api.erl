%%% @doc API handler: POST /api/irc/channels/:channel_id/join
%%%
%%% Ensures a relay exists for the channel and signals the caller's
%%% SSE stream to join the channel's pg group.
%%%
%%% Body: {"stream_pid": "<pid_string>"} — the SSE handler pid to join
%%% (passed from the frontend via stream coordination)
%%% @end
-module(join_irc_channel_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ChannelId = cowboy_req:binding(channel_id, Req0),
    %% Ensure a relay gen_server exists for this channel
    relay_irc_message_sup:ensure_relay(ChannelId),
    %% Signal all local SSE stream handlers to join this channel
    Members = pg:get_members(pg, irc_stream),
    lists:foreach(fun(Pid) -> Pid ! {join_channel, ChannelId} end, Members),
    hecate_api_utils:json_ok(#{channel_id => ChannelId, joined => true}, Req0).
