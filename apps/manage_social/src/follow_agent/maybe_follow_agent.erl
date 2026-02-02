-module(maybe_follow_agent).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

handle(Command) ->
    #{follower_identity := Follower, followed_identity := Followed} = follow_agent_v1:to_map(Command),
    case Follower =/= Followed of
        true ->
            Event = agent_followed_v1:new(Follower, Followed, erlang:system_time(millisecond)),
            {ok, [agent_followed_v1:to_map(Event)]};
        false ->
            {error, cannot_follow_self}
    end.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(follow_agent_v1:follow_agent_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FollowerIdentity = maps:get(follower_identity, follow_agent_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = follow_agent_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(FollowerIdentity, Timestamp),
        command_type = follow_agent,
        aggregate_type = social_aggregate,
        aggregate_id = FollowerIdentity,
        payload = CmdMap#{command_type => follow_agent},
        metadata = #{timestamp => Timestamp},
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
    <<"cmd-follow_agent-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
