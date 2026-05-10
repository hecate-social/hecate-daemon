%%% @doc Public library API exposed to `serve_https_over_mesh'.
%%%
%%% This is the SINGLE module the HTTPS-proxy slice imports from
%%% this slice. No other internals are stable for cross-slice
%%% consumption.
%%%
%%% PLAN_DNS_OVER_MESH_PART1 §8 + ROOT §"Dependency graph" specify
%%% this contract:
%%%
%%%   resolve_qname_to_mri(QName) -> {ok, Mri} | {error, Reason}
%%%   verify_trust_chain(Mri, LeafType) -> {ok, Record} | {error, Reason}
%%%
%%% Phase 0: stub. Re-exports the underlying Phase-0 stubs so the
%%% HTTPS slice can be scaffolded against the contract. Phase 1
%%% wires the stubs to working implementations.
%%% @end
-module(library_api).

-export([resolve_qname_to_mri/1, verify_trust_chain/2]).

-spec resolve_qname_to_mri(binary()) -> {ok, binary()} | {error, atom()}.
resolve_qname_to_mri(QName) ->
    resolve_qname_to_mri:resolve(QName).

-spec verify_trust_chain(binary(), atom()) -> {ok, map()} | {error, atom()}.
verify_trust_chain(Mri, LeafType) ->
    verify_trust_chain:verify(Mri, LeafType).
