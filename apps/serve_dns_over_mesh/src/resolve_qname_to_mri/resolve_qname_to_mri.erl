%%% @doc Top-level dispatcher: takes a mesh qname, derives its
%%% MRI type from the type-discriminator label (`_u`, `_a`, `_s`,
%%% `_p`, etc.), delegates to the per-type module for the rest of
%%% the algebra.
%%%
%%% Phase 0: stub. Phase 1 implements the dispatch + each per-type
%%% rule (see PLAN_DNS_OVER_MESH_PART1 §3.1 type discriminator
%%% table).
%%% @end
-module(resolve_qname_to_mri).

-export([resolve/1]).

-spec resolve(binary()) -> {ok, binary()} | {error, atom()}.
resolve(_QName) ->
    {error, resolve_qname_to_mri_not_yet_implemented}.
