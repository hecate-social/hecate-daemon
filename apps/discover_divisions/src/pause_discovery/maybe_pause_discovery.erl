-module(maybe_pause_discovery).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case pause_discovery_v1:validate(Cmd) of
        ok ->
            Event = discovery_paused_v1:new(#{
                venture_id => pause_discovery_v1:get_venture_id(Cmd),
                reason => pause_discovery_v1:get_reason(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = pause_discovery_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(VentureId, Timestamp),
        command_type = pause_discovery,
        aggregate_type = discovery_aggregate,
        aggregate_id = VentureId,
        payload = pause_discovery_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => discovery_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => discover_divisions_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

generate_command_id(VentureId, Timestamp) ->
    Unique = integer_to_binary(erlang:unique_integer([positive])),
    Hash = crypto:hash(sha256, <<VentureId/binary, (integer_to_binary(Timestamp))/binary, "-", Unique/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
