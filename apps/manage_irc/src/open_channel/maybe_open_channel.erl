%%% @doc maybe_open_channel handler
%%% Business logic for opening IRC channels.
-module(maybe_open_channel).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle open_channel_v1 command (business logic only)
-spec handle(open_channel_v1:open_channel_v1()) ->
    {ok, [channel_opened_v1:channel_opened_v1()]} | {error, term()}.
handle(Cmd) ->
    Name = open_channel_v1:get_name(Cmd),
    case validate_command(Name) of
        ok ->
            Event = channel_opened_v1:new(#{
                channel_id => open_channel_v1:get_channel_id(Cmd),
                name => Name,
                topic => open_channel_v1:get_topic(Cmd),
                opened_by => open_channel_v1:get_opened_by(Cmd)
            }),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(open_channel_v1:open_channel_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ChannelId = open_channel_v1:get_channel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = open_channel,
        aggregate_type = irc_channel_aggregate,
        aggregate_id = ChannelId,
        payload = open_channel_v1:to_map(Cmd),
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
validate_command(Name) when is_binary(Name), byte_size(Name) > 0 -> ok;
validate_command(_) -> {error, invalid_name}.
