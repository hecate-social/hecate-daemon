%%% @doc CT suite scaffold for failure_mode tests. Phase 0: empty
%%% placeholder so rebar3 ct discovers the module. Phase 1 fills
%%% in real cases as each capability lands.
%%% @end
-module(failure_mode_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([scaffold/1]).

all() -> [scaffold].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

scaffold(_Config) ->
    %% Phase 1 will replace this with real cases; for now we just
    %% want the suite to be discoverable + runnable so the harness
    %% structure exists.
    ok.
