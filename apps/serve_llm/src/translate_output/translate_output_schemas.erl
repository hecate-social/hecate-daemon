%%% @doc Schema registry for LLM output translation.
%%%
%%% Each schema defines how to extract structured data from raw LLM output.
%%% Schemas can be rule-based (fast, deterministic) or LLM-assisted (semantic).
%%% @end
-module(translate_output_schemas).

-export([get/1, list/0]).

-spec get(binary()) -> {ok, map()} | {error, unknown_schema}.
get(<<"vision_document">>) ->
    {ok, #{
        requires_llm => false,
        extractor => fun extract_vision_document/1
    }};
get(<<"notation_output">>) ->
    {ok, #{
        requires_llm => false,
        extractor => fun extract_notation/1
    }};
get(<<"knowledge_extraction">>) ->
    {ok, #{
        requires_llm => true,
        model_preference => <<"haiku">>,
        extraction_prompt => knowledge_extraction_prompt()
    }};
get(_) ->
    {error, unknown_schema}.

-spec list() -> [binary()].
list() ->
    [<<"vision_document">>, <<"notation_output">>, <<"knowledge_extraction">>].

%%% ===================================================================
%%% Schema Extractors
%%% ===================================================================

%% @doc Extract structured vision document from raw LLM output.
%% Returns: #{markdown, brief, sections, complete}
extract_vision_document(RawContent) ->
    Cleaned = strip_think_blocks(RawContent),
    Stripped = strip_code_fences(Cleaned),
    Trimmed = string:trim(Stripped),
    Sections = extract_sections(Trimmed),
    Brief = extract_brief(Trimmed),
    Complete = not has_hypotheticals(Trimmed),
    {ok, #{
        markdown => iolist_to_binary(Trimmed),
        brief => Brief,
        sections => Sections,
        complete => Complete
    }}.

%% @doc Extract notation output (event storming notation, etc.)
extract_notation(RawContent) ->
    Cleaned = strip_think_blocks(RawContent),
    Stripped = strip_code_fences(Cleaned),
    Trimmed = string:trim(Stripped),
    {ok, #{
        content => iolist_to_binary(Trimmed),
        format => detect_notation_format(Trimmed)
    }}.

%%% ===================================================================
%%% Heuristic Helpers
%%% ===================================================================

%% @doc Strip <think>...</think> blocks (DeepSeek, Qwen reasoning traces).
strip_think_blocks(Content) when is_binary(Content) ->
    strip_think_blocks_loop(Content);
strip_think_blocks(Content) ->
    strip_think_blocks(iolist_to_binary(Content)).

strip_think_blocks_loop(Content) ->
    case binary:match(Content, <<"<think>">>) of
        nomatch ->
            Content;
        {Start, _} ->
            case binary:match(Content, <<"</think>">>) of
                nomatch ->
                    %% Unclosed think tag — strip from <think> to end
                    binary:part(Content, 0, Start);
                {End, EndLen} ->
                    Before = binary:part(Content, 0, Start),
                    After = binary:part(Content, End + EndLen, byte_size(Content) - End - EndLen),
                    strip_think_blocks_loop(<<Before/binary, After/binary>>)
            end
    end.

%% @doc Strip markdown code fences (```markdown, ```md, ```, etc.)
strip_code_fences(Content) when is_binary(Content) ->
    Lines = binary:split(Content, <<"\n">>, [global]),
    {Filtered, _InFence} = lists:foldl(fun(Line, {Acc, InFence}) ->
        Trimmed = string:trim(Line),
        case is_fence_marker(Trimmed) of
            true when not InFence ->
                {Acc, true};
            true when InFence ->
                {Acc, false};
            false ->
                {[Line | Acc], InFence}
        end
    end, {[], false}, Lines),
    iolist_to_binary(lists:join(<<"\n">>, lists:reverse(Filtered))).

is_fence_marker(Line) ->
    case Line of
        <<"```", _/binary>> -> true;
        <<"~~~", _/binary>> -> true;
        _ -> false
    end.

%% @doc Extract section headings from markdown content.
extract_sections(Content) when is_binary(Content) ->
    Lines = binary:split(Content, <<"\n">>, [global]),
    [extract_heading_text(L) || L <- Lines, is_heading(L)].

is_heading(<<"#", _/binary>>) -> true;
is_heading(_) -> false.

extract_heading_text(Line) ->
    Stripped = string:trim(Line, leading, "#"),
    iolist_to_binary(string:trim(Stripped)).

%% @doc Extract brief (first non-heading, non-empty line or first sentence).
extract_brief(Content) when is_binary(Content) ->
    Lines = binary:split(Content, <<"\n">>, [global]),
    find_brief(Lines).

find_brief([]) -> undefined;
find_brief([Line | Rest]) ->
    Trimmed = string:trim(Line),
    case Trimmed of
        <<>> -> find_brief(Rest);
        <<"#", _/binary>> -> find_brief(Rest);
        _ ->
            %% Take first sentence or first 200 chars
            truncate_brief(Trimmed, 200)
    end.

truncate_brief(Text, MaxLen) when byte_size(Text) =< MaxLen ->
    Text;
truncate_brief(Text, MaxLen) ->
    <<Prefix:MaxLen/binary, _/binary>> = Text,
    <<Prefix/binary, "...">>.

%% @doc Check if content contains hypothetical language.
has_hypotheticals(Content) ->
    Markers = [<<"[TODO">>, <<"[TBD">>, <<"[PLACEHOLDER">>,
               <<"hypothetically">>, <<"could potentially">>],
    lists:any(fun(M) ->
        case binary:match(Content, M) of
            nomatch -> false;
            _ -> true
        end
    end, Markers).

%% @doc Detect notation format from content structure.
detect_notation_format(Content) ->
    case binary:match(Content, <<"NOTATION_START">>) of
        {_, _} -> <<"hecate_notation">>;
        nomatch ->
            case binary:match(Content, <<"```json">>) of
                {_, _} -> <<"json">>;
                nomatch -> <<"markdown">>
            end
    end.

%%% ===================================================================
%%% LLM-Assisted Schema Prompts
%%% ===================================================================

knowledge_extraction_prompt() ->
    <<"You are a knowledge extraction assistant. Given the following content, "
      "extract:\n"
      "1. **entities**: Named things (concepts, systems, users, constraints) "
      "with type, name, and brief description\n"
      "2. **relationships**: How entities relate (depends_on, targets, "
      "constrains, etc.) with from/to entity names and relationship type\n"
      "3. **insights**: Key decisions, preferences, or learnings as short "
      "statements\n\n"
      "Return valid JSON with this structure:\n"
      "{\"entities\": [{\"name\": \"...\", \"type\": \"...\", "
      "\"description\": \"...\"}],\n"
      " \"relationships\": [{\"from\": \"...\", \"to\": \"...\", "
      "\"type\": \"...\"}],\n"
      " \"insights\": [\"...\"]}\n\n"
      "Content:\n">>.
