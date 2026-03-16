%%% @doc Multi-turn agentic loop with tool calling.
%%%
%%% Calls the LLM with tools, executes any tool calls, appends results,
%%% and loops until the LLM responds with text only (no tool calls)
%%% or the max iteration limit is reached.
%%%
%%% This is a generic capability — any agent can use it, not just meditation.
%%% @end
-module(run_agent_with_tools).

-export([run/4]).

-define(MAX_ITERATIONS, 10).
-define(AVAILABLE_TOOLS, #{
    <<"web_search">> => fun execute_web_search/1,
    <<"web_fetch">> => fun execute_web_fetch/1
}).

-spec run(binary(), [map()], [map()], map()) -> {ok, binary()} | {error, term()}.
run(Model, Messages, Tools, Opts) ->
    MaxIter = maps:get(max_iterations, Opts, ?MAX_ITERATIONS),
    loop(Model, Messages, Tools, Opts, 0, MaxIter).

%% Internal

loop(_Model, _Messages, _Tools, _Opts, Iteration, MaxIter) when Iteration >= MaxIter ->
    {error, max_iterations_reached};

loop(Model, Messages, Tools, Opts, Iteration, MaxIter) ->
    LlmOpts = Opts#{tools => Tools},
    logger:info("[run_agent_with_tools] iteration ~B, model=~s", [Iteration, Model]),
    case chat_to_llm:chat(Model, Messages, LlmOpts) of
        {ok, Response} ->
            case extract_tool_calls(Response) of
                [] ->
                    %% No tool calls — LLM is done, extract final text
                    Content = extract_content(Response),
                    {ok, Content};
                ToolCalls ->
                    %% Execute each tool call and build tool result messages
                    AssistantMsg = build_assistant_message(Response),
                    ToolResultMsgs = execute_tool_calls(ToolCalls),
                    NewMessages = Messages ++ [AssistantMsg | ToolResultMsgs],
                    loop(Model, NewMessages, Tools, Opts, Iteration + 1, MaxIter)
            end;
        {error, _} = Err ->
            Err
    end.

extract_tool_calls(#{tool_calls := Calls}) when is_list(Calls), Calls =/= [] -> Calls;
extract_tool_calls(#{content := Content}) when is_list(Content) ->
    [Block || Block <- Content, is_map(Block), maps:get(type, Block, undefined) =:= <<"tool_use">>];
extract_tool_calls(_) -> [].

extract_content(#{message := #{content := C}}) when is_binary(C) -> C;
extract_content(#{content := [#{text := T} | _]}) -> T;
extract_content(#{content := C}) when is_binary(C) -> C;
extract_content(_) -> <<>>.

build_assistant_message(#{content := Content}) when is_list(Content) ->
    #{role => <<"assistant">>, content => Content};
build_assistant_message(Response) ->
    #{role => <<"assistant">>, content => extract_content(Response)}.

execute_tool_calls(ToolCalls) ->
    lists:map(fun execute_single_tool/1, ToolCalls).

execute_single_tool(#{id := ToolId, name := Name, input := Input}) ->
    execute_tool_by_name(ToolId, Name, Input);
execute_single_tool(ToolCall) ->
    %% Fallback for different response formats
    Name = maps:get(name, ToolCall, maps:get(<<"name">>, ToolCall, <<"unknown">>)),
    Id = maps:get(id, ToolCall, maps:get(<<"id">>, ToolCall, <<"unknown">>)),
    Input = maps:get(input, ToolCall,
                maps:get(<<"input">>, ToolCall,
                    maps:get(arguments, ToolCall,
                        maps:get(<<"arguments">>, ToolCall, #{})))),
    execute_tool_by_name(Id, Name, Input).

execute_tool_by_name(ToolId, Name, Input) ->
    Result = case Name of
        <<"web_search">> -> execute_web_search(Input);
        <<"web_fetch">> -> execute_web_fetch(Input);
        _ ->
            logger:warning("[run_agent_with_tools] unknown tool: ~s", [Name]),
            <<"Error: unknown tool">>
    end,
    #{
        role => <<"user">>,
        content => [#{
            type => <<"tool_result">>,
            tool_use_id => ToolId,
            content => ensure_binary(Result)
        }]
    }.

execute_web_search(Input) ->
    Query = maps:get(<<"query">>, Input, maps:get(query, Input, <<>>)),
    case web_search:search(Query) of
        {ok, Results} ->
            format_search_results(Results);
        {error, Reason} ->
            iolist_to_binary(io_lib:format("Search error: ~p", [Reason]))
    end.

execute_web_fetch(Input) ->
    Url = maps:get(<<"url">>, Input, maps:get(url, Input, <<>>)),
    case web_fetch:fetch(Url) of
        {ok, Text} -> Text;
        {error, Reason} ->
            iolist_to_binary(io_lib:format("Fetch error: ~p", [Reason]))
    end.

format_search_results(Results) ->
    Formatted = lists:map(fun(#{title := T, url := U, snippet := S}) ->
        <<"## ", T/binary, "\nURL: ", U/binary, "\n", S/binary, "\n">>
    end, Results),
    iolist_to_binary(lists:join(<<"\n---\n">>, Formatted)).

ensure_binary(V) when is_binary(V) -> V;
ensure_binary(V) -> iolist_to_binary(io_lib:format("~p", [V])).
