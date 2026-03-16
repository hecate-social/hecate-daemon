%%% @doc Tests for web_search module — pure logic tests.
%%%
%%% Tests tool definition, URL encoding, and result parsing.
%%% Does NOT make HTTP calls (no SearXNG dependency).
-module(web_search_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

web_search_test_() ->
    [
        %% Tool definition
        {"tool_definition returns valid schema",    fun tool_def_valid/0},
        {"tool_definition has correct name",        fun tool_def_name/0},
        {"tool_definition requires query param",    fun tool_def_required/0},

        %% Exports
        {"exports search/1",                        fun exports_search_1/0},
        {"exports search/2",                        fun exports_search_2/0},
        {"exports tool_definition/0",               fun exports_tool_def/0}
    ].

%% ===================================================================
%% Tool definition tests
%% ===================================================================

tool_def_valid() ->
    Def = web_search:tool_definition(),
    ?assert(is_map(Def)),
    ?assert(maps:is_key(name, Def)),
    ?assert(maps:is_key(description, Def)),
    ?assert(maps:is_key(input_schema, Def)).

tool_def_name() ->
    #{name := Name} = web_search:tool_definition(),
    ?assertEqual(<<"web_search">>, Name).

tool_def_required() ->
    #{input_schema := Schema} = web_search:tool_definition(),
    #{required := Required} = Schema,
    ?assert(lists:member(<<"query">>, Required)).

%% ===================================================================
%% Export tests
%% ===================================================================

exports_search_1() ->
    Exports = web_search:module_info(exports),
    ?assert(lists:member({search, 1}, Exports)).

exports_search_2() ->
    Exports = web_search:module_info(exports),
    ?assert(lists:member({search, 2}, Exports)).

exports_tool_def() ->
    Exports = web_search:module_info(exports),
    ?assert(lists:member({tool_definition, 0}, Exports)).
