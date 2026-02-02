%%% @doc Handler for record_follower command
%%% Records that someone followed one of my identities (from mesh fact)
-module(maybe_record_follower).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

%% @doc Handle the command and produce events
handle(Command) ->
    #{
        follower_identity := Follower,
        my_identity := MyIdentity,
        followed_at := FollowedAt
    } = record_follower_v1:to_map(Command),

    %% Validate: follower can't be me
    case Follower =/= MyIdentity of
        true ->
            RecordedAt = erlang:system_time(millisecond),
            Event = follower_recorded_v1:new(Follower, MyIdentity, FollowedAt, RecordedAt),
            {ok, [follower_recorded_v1:to_map(Event)]};
        false ->
            {error, cannot_record_self_follow}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(record_follower_v1:record_follower_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = record_follower_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = record_follower_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = record_follower,
        aggregate_type = my_followers_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => record_follower},
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
    <<"cmd-record_follower-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
