%%% @doc Public library API for serve_dns_over_mesh. Per slimmed
%%% PLAN_DNS_OVER_MESH_PART1 §8, this slice exposes ONLY the
%%% qname↔MRI codec to sibling Tier-2 wire bridges.
%%%
%%% Naming + trust verification + caching live in
%%% `resolve_mesh_names' (Tier-1). Sibling bridges (HTTPS, mDNS,
%%% etc.) translate their wire-protocol's name carrier (SNI,
%%% mDNS service name) to a qname, then call this codec to get an
%%% MRI, then call `resolve_mesh_names_api:resolve/2' for the
%%% actual lookup.
%%%
%%% @end
-module(serve_dns_over_mesh_api).

-export([qname_to_mri/1, mri_to_qname/1]).

%% @doc Translate a DNS qname (RFC 1035 dotted form, with or
%% without trailing dot) into its MRI form. Pure function; no I/O.
-spec qname_to_mri(QName :: binary()) -> {ok, binary()} | {error, atom()}.
qname_to_mri(QName) ->
    qname_to_mri:resolve(QName).

%% @doc Translate an MRI back into its DNS qname form. Used by RR
%% synthesis (PTR target, NS / SOA MNAME pointing at a station's
%% `_st' qname) and by sibling bridges that need to surface a
%% mesh-resolved address as a hostname.
-spec mri_to_qname(Mri :: binary() | map()) -> {ok, binary()} | {error, atom()}.
mri_to_qname(Mri) ->
    qname_to_mri:format(Mri).
