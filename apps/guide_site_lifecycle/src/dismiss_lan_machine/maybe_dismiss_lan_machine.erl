%%% @doc Handler for dismiss_lan_machine command.
-module(maybe_dismiss_lan_machine).

-export([handle_from_map/1, dispatch/2]).

-dialyzer({nowarn_function, [dispatch/2]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    Observer = maps:get(observer, Payload, maps:get(<<"observer">>, Payload, <<>>)),
    case byte_size(Observer) of
        0 -> {error, observer_required};
        _ ->
            Event = #{
                event_type => <<"lan_machine_dismissed_v1">>,
                observer => Observer,
                dismissed_at => erlang:system_time(millisecond)
            },
            {ok, [Event]}
    end.

-spec dispatch(binary(), binary()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(MAC, Observer) ->
    StreamId = lan_machine_aggregate:stream_id(MAC, Observer),
    EvoqCmd = #evoq_command{
        command_type = dismiss_lan_machine,
        aggregate_type = lan_machine_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => dismiss_lan_machine,
            mac => MAC,
            observer => Observer
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => site_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
