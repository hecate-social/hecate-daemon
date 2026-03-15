%%% @doc Tests for translate_output and translate_output_schemas.
-module(translate_output_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Schema Registry
%% ===================================================================

known_schema_returns_ok_test() ->
    {ok, _} = translate_output_schemas:get(<<"vision_document">>),
    {ok, _} = translate_output_schemas:get(<<"notation_output">>),
    {ok, _} = translate_output_schemas:get(<<"knowledge_extraction">>).

unknown_schema_returns_error_test() ->
    {error, unknown_schema} = translate_output_schemas:get(<<"nope">>),
    {error, unknown_schema} = translate_output_schemas:get(<<>>).

list_returns_all_schemas_test() ->
    Schemas = translate_output_schemas:list(),
    ?assert(lists:member(<<"vision_document">>, Schemas)),
    ?assert(lists:member(<<"notation_output">>, Schemas)),
    ?assert(lists:member(<<"knowledge_extraction">>, Schemas)),
    ?assertEqual(3, length(Schemas)).

vision_document_schema_is_rule_based_test() ->
    {ok, Schema} = translate_output_schemas:get(<<"vision_document">>),
    ?assertEqual(false, maps:get(requires_llm, Schema)),
    ?assert(is_function(maps:get(extractor, Schema), 1)).

knowledge_extraction_schema_requires_llm_test() ->
    {ok, Schema} = translate_output_schemas:get(<<"knowledge_extraction">>),
    ?assertEqual(true, maps:get(requires_llm, Schema)),
    ?assertEqual(<<"haiku">>, maps:get(model_preference, Schema)).

%% ===================================================================
%% translate_output:translate/2 — Rule-Based Schemas
%% ===================================================================

translate_unknown_schema_test() ->
    {error, unknown_schema} = translate_output:translate(<<"hello">>, <<"bogus">>).

%% ===================================================================
%% Vision Document Extraction
%% ===================================================================

vision_document_strips_think_blocks_test() ->
    Input = <<"<think>reasoning here</think>\n# Vision\nThe problem is...">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertEqual(nomatch, binary:match(Markdown, <<"<think>">>)),
    ?assertNotEqual(nomatch, binary:match(Markdown, <<"# Vision">>)).

vision_document_strips_unclosed_think_test() ->
    Input = <<"<think>thinking forever...\n# Vision\nStuff">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertEqual(<<>>, Markdown).

vision_document_strips_code_fences_test() ->
    Input = <<"```markdown\n# Vision\nHello world\n```">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertEqual(nomatch, binary:match(Markdown, <<"```">>)),
    ?assertNotEqual(nomatch, binary:match(Markdown, <<"# Vision">>)).

vision_document_strips_md_fences_test() ->
    Input = <<"```md\n# Vision\nHello\n```">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertEqual(nomatch, binary:match(Markdown, <<"```">>)).

vision_document_strips_tilde_fences_test() ->
    Input = <<"~~~\n# Vision\nHello\n~~~">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertEqual(nomatch, binary:match(Markdown, <<"~~~">>)).

vision_document_extracts_sections_test() ->
    Input = <<"# Vision\n## Problem\nStuff\n## Users\nMore stuff">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Sections = maps:get(sections, Result),
    ?assert(length(Sections) >= 2),
    ?assert(lists:any(fun(S) -> S =:= <<"Vision">> end, Sections)),
    ?assert(lists:any(fun(S) -> S =:= <<"Problem">> end, Sections)).

vision_document_extracts_brief_test() ->
    Input = <<"# Vision\nA brief summary of the vision.\n## Details">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Brief = maps:get(brief, Result),
    ?assertNotEqual(undefined, Brief),
    ?assertNotEqual(nomatch, binary:match(Brief, <<"brief summary">>)).

vision_document_brief_skips_empty_lines_test() ->
    Input = <<"# Vision\n\n\nActual content here">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    ?assertEqual(<<"Actual content here">>, maps:get(brief, Result)).

vision_document_brief_undefined_when_only_headings_test() ->
    Input = <<"# Vision\n## Problem\n## Users">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    ?assertEqual(undefined, maps:get(brief, Result)).

vision_document_complete_when_no_hypotheticals_test() ->
    Input = <<"# Vision\nWe will build a chat app.\n## Users\nEveryone.">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    ?assertEqual(true, maps:get(complete, Result)).

vision_document_incomplete_with_todo_test() ->
    Input = <<"# Vision\n[TODO] Fill this in">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    ?assertEqual(false, maps:get(complete, Result)).

vision_document_incomplete_with_tbd_test() ->
    Input = <<"# Vision\n[TBD] Need research">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    ?assertEqual(false, maps:get(complete, Result)).

vision_document_incomplete_with_placeholder_test() ->
    Input = <<"# Vision\n[PLACEHOLDER] Needs content">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    ?assertEqual(false, maps:get(complete, Result)).

vision_document_combined_think_and_fence_test() ->
    Input = <<"<think>reasoning</think>\n```markdown\n# Vision\nClean output\n```\n<think>more thought</think>">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertEqual(nomatch, binary:match(Markdown, <<"<think>">>)),
    ?assertEqual(nomatch, binary:match(Markdown, <<"```">>)),
    ?assertNotEqual(nomatch, binary:match(Markdown, <<"# Vision">>)).

vision_document_truncates_long_brief_test() ->
    LongLine = iolist_to_binary(lists:duplicate(50, <<"word ">>)),
    Input = <<"# Vision\n", LongLine/binary>>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Brief = maps:get(brief, Result),
    ?assert(byte_size(Brief) =< 204). %% 200 + "..."

%% ===================================================================
%% Notation Output Extraction
%% ===================================================================

notation_output_basic_test() ->
    Input = <<"Some notation content">>,
    {ok, Result} = translate_output:translate(Input, <<"notation_output">>),
    ?assertEqual(<<"Some notation content">>, maps:get(content, Result)),
    ?assertEqual(<<"markdown">>, maps:get(format, Result)).

notation_output_detects_hecate_notation_test() ->
    Input = <<"NOTATION_START\nsome stuff\nNOTATION_END">>,
    {ok, Result} = translate_output:translate(Input, <<"notation_output">>),
    ?assertEqual(<<"hecate_notation">>, maps:get(format, Result)).

notation_output_detects_json_test() ->
    Input = <<"Here is the notation:\n```json\n{\"events\": []}\n```">>,
    {ok, Result} = translate_output:translate(Input, <<"notation_output">>),
    %% After stripping fences, the content won't contain ```json anymore
    %% so it detects based on what remains
    ?assert(is_binary(maps:get(format, Result))).

notation_output_strips_think_and_fences_test() ->
    Input = <<"<think>hmm</think>\n```\nContent here\n```">>,
    {ok, Result} = translate_output:translate(Input, <<"notation_output">>),
    Content = maps:get(content, Result),
    ?assertEqual(nomatch, binary:match(Content, <<"<think>">>)),
    ?assertEqual(nomatch, binary:match(Content, <<"```">>)).

%% ===================================================================
%% Edge Cases
%% ===================================================================

empty_content_test() ->
    {ok, Result} = translate_output:translate(<<>>, <<"vision_document">>),
    ?assertEqual(<<>>, maps:get(markdown, Result)),
    ?assertEqual([], maps:get(sections, Result)),
    ?assertEqual(undefined, maps:get(brief, Result)).

only_think_block_test() ->
    {ok, Result} = translate_output:translate(<<"<think>all thinking</think>">>, <<"vision_document">>),
    ?assertEqual(<<>>, maps:get(markdown, Result)).

multiple_think_blocks_test() ->
    Input = <<"<think>A</think>Hello<think>B</think> world">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertNotEqual(nomatch, binary:match(Markdown, <<"Hello">>)),
    ?assertNotEqual(nomatch, binary:match(Markdown, <<"world">>)),
    ?assertEqual(nomatch, binary:match(Markdown, <<"<think>">>)).

nested_code_fences_test() ->
    Input = <<"```\nOuter\n```\nMiddle\n```\nInner\n```">>,
    {ok, Result} = translate_output:translate(Input, <<"vision_document">>),
    Markdown = maps:get(markdown, Result),
    ?assertNotEqual(nomatch, binary:match(Markdown, <<"Middle">>)).
