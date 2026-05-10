%%% @doc Top-level dispatcher: takes a verified leaf record + the
%%% original qtype, delegates to the per-qtype synthesiser.
%%%
%%% Phase 0: stub. Per-qtype rules are in `synth_<qtype>.erl'
%%% modules. PLAN_DNS_OVER_MESH_PART1 §7 has the qtype → record
%%% source mapping.
%%% @end
-module(synthesize_rr_set).

-export([synthesise/2]).

-spec synthesise(Leaf :: map(), QType :: atom()) ->
    {ok, [term()]} | {error, atom()}.
synthesise(_Leaf, _QType) ->
    {error, synthesize_rr_set_not_yet_implemented}.
