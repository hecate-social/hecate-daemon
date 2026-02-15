%%% @doc maybe_close_channel handler
%%% Business logic for closing IRC channels.
-module(maybe_close_channel).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-spec handle(close_channel_v1:close_channel_v1()) ->
    {ok, [channel_closed_v1:channel_closed_v1()]} | {error, term()}.
handle(Cmd) ->
    ChannelId = close_channel_v1:get_channel_id(Cmd),
    case validate_command(ChannelId) of
        ok ->
            Event = channel_closed_v1:new(#{
                channel_id => ChannelId,
                closed_by => close_channel_v1:get_closed_by(Cmd)
            }),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(close_channel_v1:close_channel_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ChannelId = close_channel_v1:get_channel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = close_channel,
        aggregate_type = irc_channel_aggregate,
        aggregate_id = ChannelId,
        payload = close_channel_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => irc_channel_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal
validate_command(ChannelId) when is_binary(ChannelId), byte_size(ChannelId) > 0 -> ok;
validate_command(_) -> {error, invalid_channel_id}.
