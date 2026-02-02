#!/bin/bash
set -euo pipefail

SCENARIO="${1:-all}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== Macula Hecate Performance Test Suite ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Compile if needed
echo "Compiling project..."
rebar3 compile || {
    echo "ERROR: Compilation failed"
    exit 1
}

# Start Erlang shell with performance test module
echo ""
echo "Starting performance tests (scenario: $SCENARIO)..."
echo ""

erl -pa _build/default/lib/*/ebin \
    -pa apps/*/ebin \
    -eval "
        % Start all applications
        Apps = [
            manage_capabilities,
            manage_social,
            manage_subscriptions,
            manage_identities,
            manage_ucan,
            query_capabilities,
            query_social,
            query_subscriptions,
            query_identities,
            query_ucan
        ],

        lists:foreach(fun(App) ->
            case application:ensure_all_started(App) of
                {ok, _} -> io:format(\"Started ~p~n\", [App]);
                {error, Reason} -> io:format(\"WARNING: Failed to start ~p: ~p~n\", [App, Reason])
            end
        end, Apps),

        io:format(\"~nAll applications started.~n~n\"),

        % Run tests
        case \"$SCENARIO\" of
            \"all\" ->
                Results = perf_test_runner:run_all(),
                io:format(\"~n=== ALL TESTS COMPLETE ===~n\"),
                halt(0);
            Scenario ->
                ScenarioAtom = list_to_atom(Scenario),
                Result = perf_test_runner:run_scenario(ScenarioAtom),
                io:format(\"~n=== TEST COMPLETE ===~n\"),
                halt(0)
        end
    " \
    -noshell

echo ""
echo "Performance tests complete!"
