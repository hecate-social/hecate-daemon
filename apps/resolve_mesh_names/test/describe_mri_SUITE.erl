%%% @doc CT scaffold for the describe_mri desk. Phase 0: one trivial
%%% passing case so the suite is wired before Phase 1 fills in
%%% real cases per PLAN_RESOLVE_MESH_NAMES_PART1 §8.1.
%%% @end
-module(describe_mri_SUITE).

-export([all/0, scaffold/1]).

all() -> [scaffold].

scaffold(_Config) -> ok.
