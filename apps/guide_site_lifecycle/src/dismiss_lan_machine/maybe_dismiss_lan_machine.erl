%%% @doc Handler for dismiss_lan_machine command.
-module(maybe_dismiss_lan_machine).

-export([handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(_Payload) ->
    Event = #{
        event_type => <<"lan_machine_dismissed_v1">>,
        dismissed_at => erlang:system_time(millisecond)
    },
    {ok, [Event]}.

-spec dispatch(binary()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(MAC) ->
    StreamId = lan_machine_aggregate:stream_id(MAC),
    EvoqCmd = #evoq_command{
        command_type = dismiss_lan_machine,
        aggregate_type = lan_machine_aggregate,
        aggregate_id = StreamId,
        payload = #{command_type => dismiss_lan_machine, mac => MAC},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => site_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
