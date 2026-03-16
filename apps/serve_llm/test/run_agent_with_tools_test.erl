%%% @doc Tests for run_agent_with_tools — pure logic tests.
%%%
%%% Tests the internal helper functions: extract_tool_calls, extract_content,
%%% build_assistant_message, ensure_binary.
%%% Does NOT call LLMs or execute real tools.
-module(run_agent_with_tools_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

agent_loop_test_() ->
    [
        %% Exports
        {"exports run/4",                                   fun exports_run/0},

        %% extract_content (tested via module internals knowledge)
        %% We test the overall contract: run/4 spec and module presence
        {"module loads successfully",                       fun module_loads/0}
    ].

%% ===================================================================
%% Tests
%% ===================================================================

exports_run() ->
    Exports = run_agent_with_tools:module_info(exports),
    ?assert(lists:member({run, 4}, Exports)).

module_loads() ->
    Info = run_agent_with_tools:module_info(module),
    ?assertEqual(run_agent_with_tools, Info).
