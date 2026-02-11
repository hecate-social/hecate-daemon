-module(maybe_archive_design).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case archive_design_v1:validate(Cmd) of
        ok ->
            Event = design_archived_v1:new(#{
                division_id => archive_design_v1:get_division_id(Cmd),
                archived_by => archive_design_v1:get_archived_by(Cmd),
                reason => archive_design_v1:get_reason(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = archive_design_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = archive_design,
        aggregate_type = design_aggregate,
        aggregate_id = DivisionId,
        payload = archive_design_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => design_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => design_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

generate_command_id(DivisionId, Timestamp) ->
    Unique = integer_to_binary(erlang:unique_integer([positive])),
    Hash = crypto:hash(sha256, <<DivisionId/binary, (integer_to_binary(Timestamp))/binary, "-", Unique/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
