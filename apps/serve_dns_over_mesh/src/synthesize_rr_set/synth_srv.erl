%%% @doc Per-qtype RRset synthesiser for QTYPE `srv'. Phase 0
%%% stub — see PLAN_DNS_OVER_MESH_PART1 §7 for the per-qtype
%%% record-source mapping + RR encoding rules.
%%% @end
-module(synth_srv).

-export([synth/1]).

-spec synth(Leaf :: map()) -> {ok, [term()]} | {error, atom()}.
synth(_Leaf) ->
    {error, synth_srv_not_yet_implemented}.
