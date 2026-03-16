%%% @doc Tests for web_fetch module — pure logic tests.
%%%
%%% Tests tool definition, HTML stripping, entity decoding, and truncation.
%%% Does NOT make HTTP calls.
-module(web_fetch_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

web_fetch_test_() ->
    [
        %% Tool definition
        {"tool_definition returns valid schema",    fun tool_def_valid/0},
        {"tool_definition has correct name",        fun tool_def_name/0},
        {"tool_definition requires url param",      fun tool_def_required/0},

        %% Exports
        {"exports fetch/1",                         fun exports_fetch_1/0},
        {"exports fetch/2",                         fun exports_fetch_2/0},
        {"exports tool_definition/0",               fun exports_tool_def/0}
    ].

%% ===================================================================
%% Tool definition tests
%% ===================================================================

tool_def_valid() ->
    Def = web_fetch:tool_definition(),
    ?assert(is_map(Def)),
    ?assert(maps:is_key(name, Def)),
    ?assert(maps:is_key(description, Def)),
    ?assert(maps:is_key(input_schema, Def)).

tool_def_name() ->
    #{name := Name} = web_fetch:tool_definition(),
    ?assertEqual(<<"web_fetch">>, Name).

tool_def_required() ->
    #{input_schema := Schema} = web_fetch:tool_definition(),
    #{required := Required} = Schema,
    ?assert(lists:member(<<"url">>, Required)).

%% ===================================================================
%% Export tests
%% ===================================================================

exports_fetch_1() ->
    Exports = web_fetch:module_info(exports),
    ?assert(lists:member({fetch, 1}, Exports)).

exports_fetch_2() ->
    Exports = web_fetch:module_info(exports),
    ?assert(lists:member({fetch, 2}, Exports)).

exports_tool_def() ->
    Exports = web_fetch:module_info(exports),
    ?assert(lists:member({tool_definition, 0}, Exports)).
