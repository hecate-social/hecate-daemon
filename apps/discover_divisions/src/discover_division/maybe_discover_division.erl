-module(maybe_discover_division).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case discover_division_v1:validate(Cmd) of
        ok ->
            ContextName = discover_division_v1:get_context_name(Cmd),
            Discovered = maps:get(discovered_divisions, Context, #{}),
            case maps:is_key(ContextName, Discovered) of
                true ->
                    {error, division_already_discovered};
                false ->
                    Event = division_discovered_v1:new(#{
                        venture_id => discover_division_v1:get_venture_id(Cmd),
                        context_name => ContextName,
                        description => discover_division_v1:get_description(Cmd),
                        identified_by => discover_division_v1:get_identified_by(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = discover_division_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(VentureId, Timestamp),
        command_type = discover_division,
        aggregate_type = discovery_aggregate,
        aggregate_id = VentureId,
        payload = discover_division_v1:to_map(Cmd),
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
