%%% @doc Handler for spot_lan_machine command.
%%%
%%% Called by the LAN scanner when a machine is first seen
%%% or when its state changes (IP, hostname, hecate status).
-module(maybe_spot_lan_machine).

-export([handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    MAC = maps:get(mac, Payload, maps:get(<<"mac">>, Payload, <<>>)),
    case byte_size(MAC) of
        0 -> {error, mac_required};
        _ ->
            Event = #{
                event_type => <<"lan_machine_spotted_v1">>,
                mac => MAC,
                ip => maps:get(ip, Payload, maps:get(<<"ip">>, Payload, <<>>)),
                hostname => maps:get(hostname, Payload, maps:get(<<"hostname">>, Payload, <<>>)),
                interface => maps:get(interface, Payload, maps:get(<<"interface">>, Payload, <<>>)),
                ssh => maps:get(ssh, Payload, maps:get(<<"ssh">>, Payload, false)),
                hecate => maps:get(hecate, Payload, maps:get(<<"hecate">>, Payload, #{running => false})),
                spotted_at => erlang:system_time(millisecond)
            },
            {ok, [Event]}
    end.

-spec dispatch(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(#{mac := MAC} = ScanResult) ->
    StreamId = lan_machine_aggregate:stream_id(MAC),
    Payload = ScanResult#{command_type => spot_lan_machine},
    EvoqCmd = #evoq_command{
        command_type = spot_lan_machine,
        aggregate_type = lan_machine_aggregate,
        aggregate_id = StreamId,
        payload = Payload,
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => site_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
