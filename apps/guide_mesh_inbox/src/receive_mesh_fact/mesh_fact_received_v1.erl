%%% @doc mesh_fact_received_v1 domain event
%%%
%%% Internal domain event: the daemon received a FACT on a subscribed
%%% mesh topic from a remote agent. The accompanying projection
%%% (`mesh_fact_received_v1_to_mesh_activity') joins the unified
%%% mesh_activity ETS read model with `direction => in', so inbound
%%% appears alongside outbound publishes / artifact shares in
%%% `/api/mesh/inbox' and `/api/mesh/activity'.
%%%
%%% `sender_node_id' is the remote node's 32-byte ed25519 pubkey
%%% (hex). `sender_mri' is the resolved MRI when available.
%%% `sig_verified' carries the substrate's own signature verification
%%% outcome (macula validates inbound signatures at the wire layer).
%%% @end
-module(mesh_fact_received_v1).
-behaviour(evoq_event).

-export([new/1, new/6, to_map/1, from_map/1]).
-export([event_type/0]).

-record(mesh_fact_received_v1, {
    topic          :: binary(),
    fact           :: map(),
    sender_node_id :: binary() | undefined,
    sender_mri     :: binary() | undefined,
    sig_verified   :: boolean(),
    received_at    :: integer()
}).

-opaque mesh_fact_received_v1() :: #mesh_fact_received_v1{}.
-export_type([mesh_fact_received_v1/0]).

event_type() -> <<"mesh_fact_received_v1">>.

new(#{topic := T, fact := F, sender_node_id := SN, sender_mri := SM,
      sig_verified := SV, received_at := R}) ->
    new(T, F, SN, SM, SV, R).

-spec new(binary(), map(), binary() | undefined, binary() | undefined,
          boolean(), integer()) -> mesh_fact_received_v1().
new(Topic, Fact, SenderNodeId, SenderMri, SigVerified, ReceivedAt)
  when is_binary(Topic), is_map(Fact), is_boolean(SigVerified),
       is_integer(ReceivedAt) ->
    #mesh_fact_received_v1{topic = Topic, fact = Fact,
                           sender_node_id = SenderNodeId,
                           sender_mri = SenderMri,
                           sig_verified = SigVerified,
                           received_at = ReceivedAt}.

-spec to_map(mesh_fact_received_v1()) -> map().
to_map(#mesh_fact_received_v1{topic = T, fact = F, sender_node_id = SN,
                              sender_mri = SM, sig_verified = SV,
                              received_at = R}) ->
    #{
        event_type     => <<"mesh_fact_received_v1">>,
        topic          => T,
        fact           => F,
        sender_node_id => SN,
        sender_mri     => SM,
        sig_verified   => SV,
        received_at    => R
    }.

-spec from_map(map()) -> {ok, mesh_fact_received_v1()} | {error, term()}.
from_map(#{topic := T, fact := F, received_at := R} = M)
  when is_binary(T), is_map(F), is_integer(R) ->
    SN = maps:get(sender_node_id, M, undefined),
    SM = maps:get(sender_mri, M, undefined),
    SV = maps:get(sig_verified, M, false),
    {ok, #mesh_fact_received_v1{topic = T, fact = F,
                                sender_node_id = SN, sender_mri = SM,
                                sig_verified = SV, received_at = R}};
from_map(_) ->
    {error, invalid_mesh_fact_received_event}.
