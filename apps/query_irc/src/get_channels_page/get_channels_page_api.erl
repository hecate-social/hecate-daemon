%%% @doc API handler: GET /api/irc/channels
%%% Returns all open channels from the SQLite read model.
-module(get_channels_page_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Sql = "SELECT channel_id, name, topic, opened_by, status, status_label, opened_at
           FROM channels
           WHERE status & 2 = 0
           ORDER BY opened_at DESC",
    case query_irc_store:query(Sql) of
        {ok, Rows} ->
            Channels = [row_to_map(R) || R <- Rows],
            hecate_api_utils:json_ok(#{channels => Channels}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

row_to_map([ChannelId, Name, Topic, OpenedBy, Status, StatusLabel, OpenedAt]) ->
    #{
        channel_id => ChannelId,
        name => Name,
        topic => Topic,
        opened_by => OpenedBy,
        status => Status,
        status_label => StatusLabel,
        opened_at => OpenedAt
    }.
