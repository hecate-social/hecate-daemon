%%% @doc receive_mesh_fact_v1 command
%%%
%%% Substrate-initiated, NOT agent-initiated: the LISTENER
%%% (`receive_mesh_fact_listener') invokes this on every inbound FACT
%%% delivered through `hecate_mesh:subscribe/2'. The command records
%%% the event into the local inbox; no business rules are enforced at
%%% this layer (the substrate already validated signatures + dedup'd
%%% before delivery).
%%% @end
-module(receive_mesh_fact_v1).
-behaviour(evoq_command).

-export([new/1, new/6, to_map/1, from_map/1]).
-export([command_type/0]).

-record(receive_mesh_fact_v1, {
    topic          :: binary(),
    fact           :: map(),
    sender_node_id :: binary() | undefined,
    sender_mri     :: binary() | undefined,
    sig_verified   :: boolean(),
    received_at    :: integer()
}).

-opaque receive_mesh_fact_v1() :: #receive_mesh_fact_v1{}.
-export_type([receive_mesh_fact_v1/0]).

command_type() -> receive_mesh_fact_v1.

-spec new(map()) -> {ok, receive_mesh_fact_v1()} | {error, term()}.
new(#{topic := T, fact := F} = M) when is_binary(T), is_map(F) ->
    SN = maps:get(sender_node_id, M, undefined),
    SM = maps:get(sender_mri, M, undefined),
    SV = maps:get(sig_verified, M, false),
    R  = maps:get(received_at, M, erlang:system_time(millisecond)),
    {ok, new(T, F, SN, SM, SV, R)};
new(_) ->
    {error, missing_topic_or_fact}.

-spec new(binary(), map(), binary() | undefined, binary() | undefined,
          boolean(), integer()) -> receive_mesh_fact_v1().
new(Topic, Fact, SenderNodeId, SenderMri, SigVerified, ReceivedAt)
  when is_binary(Topic), is_map(Fact), is_boolean(SigVerified),
       is_integer(ReceivedAt) ->
    #receive_mesh_fact_v1{topic = Topic, fact = Fact,
                          sender_node_id = SenderNodeId,
                          sender_mri = SenderMri,
                          sig_verified = SigVerified,
                          received_at = ReceivedAt}.

-spec to_map(receive_mesh_fact_v1()) -> map().
to_map(#receive_mesh_fact_v1{topic = T, fact = F, sender_node_id = SN,
                             sender_mri = SM, sig_verified = SV,
                             received_at = R}) ->
    #{topic          => T,
      fact           => F,
      sender_node_id => SN,
      sender_mri     => SM,
      sig_verified   => SV,
      received_at    => R}.

-spec from_map(map()) -> {ok, receive_mesh_fact_v1()} | {error, term()}.
from_map(#{topic := T, fact := F, received_at := R} = M)
  when is_binary(T), is_map(F), is_integer(R) ->
    SN = maps:get(sender_node_id, M, undefined),
    SM = maps:get(sender_mri, M, undefined),
    SV = maps:get(sig_verified, M, false),
    {ok, #receive_mesh_fact_v1{topic = T, fact = F,
                               sender_node_id = SN, sender_mri = SM,
                               sig_verified = SV, received_at = R}};
from_map(_) ->
    {error, invalid_receive_mesh_fact_command}.
