%%% @doc Per-qtype RRset synthesiser for QTYPE `soa'. Phase 0
%%% stub — see PLAN_DNS_OVER_MESH_PART1 §7 for the per-qtype
%%% record-source mapping + RR encoding rules.
%%% @end
-module(synth_soa).

-export([synth/1]).

-spec synth(Leaf :: map()) -> {ok, [term()]} | {error, atom()}.
synth(_Leaf) ->
    {error, synth_soa_not_yet_implemented}.
