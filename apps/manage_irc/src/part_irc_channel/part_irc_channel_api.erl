%%% @doc API handler: POST /api/irc/channels/:channel_id/part
%%% Signals the caller's SSE stream to leave the channel's pg group.
-module(part_irc_channel_api).

-export([init/2, routes/0]).

routes() -> [{"/api/irc/channels/:channel_id/part", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ChannelId = cowboy_req:binding(channel_id, Req0),
    %% Signal all local SSE stream handlers to part this channel
    Members = pg:get_members(pg, irc_stream),
    lists:foreach(fun(Pid) -> Pid ! {part_channel, ChannelId} end, Members),
    hecate_api_utils:json_ok(#{channel_id => ChannelId, parted => true}, Req0).
