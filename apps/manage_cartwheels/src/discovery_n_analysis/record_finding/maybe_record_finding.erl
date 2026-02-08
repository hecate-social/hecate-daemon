%%% @doc maybe_record_finding handler
%%% Business logic for recording a finding during discovery.
%%% Validates the command and dispatches via evoq.
-module(maybe_record_finding).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle record_finding_v1 command (business logic only)
-spec handle(record_finding_v1:record_finding_v1()) ->
    {ok, [finding_recorded_v1:finding_recorded_v1()]} | {error, term()}.
handle(Cmd) ->
    Title = record_finding_v1:get_title(Cmd),
    Category = record_finding_v1:get_category(Cmd),
    case validate_command(Title, Category) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(record_finding_v1:record_finding_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = record_finding_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = record_finding,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = record_finding_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => cartwheel_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_cartwheels_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(Title, Category) when
    is_binary(Title), byte_size(Title) > 0,
    is_binary(Category), byte_size(Category) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    finding_recorded_v1:new(#{
        cartwheel_id => record_finding_v1:get_cartwheel_id(Cmd),
        finding_id => record_finding_v1:get_finding_id(Cmd),
        category => record_finding_v1:get_category(Cmd),
        title => record_finding_v1:get_title(Cmd),
        content => record_finding_v1:get_content(Cmd),
        priority => record_finding_v1:get_priority(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
