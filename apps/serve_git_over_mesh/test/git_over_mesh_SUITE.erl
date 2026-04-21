%%% @doc Common Test scaffold for end-to-end git-over-mesh scenarios.
%%%
%%% The full round-trip test (node A advertises, node B fetches,
%%% post-receive FACT observed) is Phase 2.1 work — it needs the
%%% streaming RPC primitive that macula SDK doesn't yet ship, plus
%%% two-node fixturing that's fragile in CI. This suite intentionally
%%% ships as a placeholder so the test shape is in place when the
%%% primitive lands.
%%%
%%% Run locally:
%%%   rebar3 ct --suite apps/serve_git_over_mesh/test/git_over_mesh_SUITE
-module(git_over_mesh_SUITE).

-include_lib("common_test/include/ct.hrl").

-export([all/0, groups/0, init_per_suite/1, end_per_suite/1]).
-export([all_ok/1]).

all() ->
    [all_ok].

groups() ->
    [].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

%%====================================================================
%% Cases
%%====================================================================

%% @doc Placeholder until streaming fetch + FACT round-trip lands.
all_ok(_Config) ->
    ok.
