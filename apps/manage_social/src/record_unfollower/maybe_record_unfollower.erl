%%% @doc Handler for record_unfollower command
-module(maybe_record_unfollower).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{
        unfollower_identity := Unfollower,
        my_identity := MyIdentity,
        unfollowed_at := UnfollowedAt
    } = record_unfollower_v1:to_map(Command),

    RecordedAt = erlang:system_time(millisecond),
    Event = unfollower_recorded_v1:new(Unfollower, MyIdentity, UnfollowedAt, RecordedAt),
    {ok, [unfollower_recorded_v1:to_map(Event)]}.

-spec dispatch(record_unfollower_v1:record_unfollower_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = record_unfollower_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = record_unfollower_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = record_unfollower,
        aggregate_type = my_followers_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => record_unfollower},
        metadata = #{timestamp => Timestamp, source => mesh_fact},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_social_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AggId, Ts) ->
    Hash = crypto:hash(sha256, <<AggId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-record_unfollower-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
