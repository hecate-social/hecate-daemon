-module(manage_irc_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/irc/channels/open",                  open_channel_api, []},
        {"/api/irc/channels/:channel_id/close",     close_channel_api, []},
        {"/api/irc/channels/:channel_id/messages",  relay_irc_message_api, []},
        {"/api/irc/channels/:channel_id/join",      join_irc_channel_api, []},
        {"/api/irc/channels/:channel_id/part",      part_irc_channel_api, []},
        {"/api/irc/channels/:channel_id/members",   get_channel_members_api, []},
        {"/api/irc/nick",                           change_nick_api, []},
        {"/api/irc/stream",                         stream_irc_api, []}
    ].
