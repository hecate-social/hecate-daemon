%%% @doc CT scaffold for the lookup_via_dht desk. Phase 0: one trivial
%%% passing case so the suite is wired before Phase 1 fills in
%%% real cases per PLAN_RESOLVE_MESH_NAMES_PART1 §8.1.
%%% @end
-module(lookup_via_dht_SUITE).

-export([all/0, scaffold/1]).

all() -> [scaffold].

scaffold(_Config) -> ok.
