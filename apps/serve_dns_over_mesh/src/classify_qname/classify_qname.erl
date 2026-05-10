%%% @doc Classifies a parsed qname as either mesh-eligible
%%% (suffix matches the configured `mesh_suffix' app env) or
%%% non-mesh (short-circuit with REFUSED).
%%%
%%% Phase 0: stub. Phase 1 will: lowercase + canonicalise the
%%% qname, check suffix against `application:get_env(serve_dns_over_mesh,
%%% mesh_suffix, "macula.io.")', return `mesh' / `not_mesh'.
%%% @end
-module(classify_qname).

-export([classify/1]).

-spec classify(binary()) -> mesh | not_mesh.
classify(_QName) ->
    %% Conservative default: not_mesh. Phase 1 implements the
    %% real suffix check. Until then every query short-circuits to
    %% REFUSED, which is the safe degraded mode (we never lie).
    not_mesh.
