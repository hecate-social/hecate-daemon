%%% @doc GET /api/observer/ets — ETS table list.
%%%
%%% Returns all ETS tables with name, type, size, memory, owner, protection.
%%% @end
-module(get_ets_tables_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/ets", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Tables = ets:all(),
    Items = lists:filtermap(fun(Tab) ->
        try
            {true, format_table(Tab)}
        catch _:_ -> false
        end
    end, Tables),
    hecate_api_utils:json_ok(#{items => Items, total => length(Items)}, Req0).

format_table(Tab) ->
    #{
        name => format_tab_name(Tab),
        id => format_tab_name(Tab),
        type => atom_to_binary(safe_info(Tab, type, set)),
        size => safe_info(Tab, size, 0),
        memory_bytes => safe_info(Tab, memory, 0) * erlang:system_info(wordsize),
        owner => format_pid(safe_info(Tab, owner, undefined)),
        protection => atom_to_binary(safe_info(Tab, protection, private)),
        read_concurrency => safe_info(Tab, read_concurrency, false),
        write_concurrency => safe_info(Tab, write_concurrency, false),
        named_table => safe_info(Tab, named_table, false)
    }.

safe_info(Tab, Key, Default) ->
    try ets:info(Tab, Key) of
        undefined -> Default;
        Val -> Val
    catch _:_ -> Default
    end.

format_tab_name(Tab) when is_atom(Tab) -> atom_to_binary(Tab);
format_tab_name(Tab) when is_reference(Tab) ->
    iolist_to_binary(io_lib:format("~p", [Tab]));
format_tab_name(Tab) ->
    iolist_to_binary(io_lib:format("~p", [Tab])).

format_pid(Pid) when is_pid(Pid) ->
    PidStr = pid_to_list(Pid),
    list_to_binary(string:trim(PidStr, both, "<>"));
format_pid(_) -> null.
