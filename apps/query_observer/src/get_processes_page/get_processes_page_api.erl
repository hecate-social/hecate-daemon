%%% @doc GET /api/observer/processes — Paginated process list.
%%%
%%% Query params: sort=memory|reductions|message_queue_len, limit=50, offset=0
%%% @end
-module(get_processes_page_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/processes", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    SortField = qs_atom(<<"sort">>, QS, memory),
    Limit = qs_int(<<"limit">>, QS, 50),
    Offset = qs_int(<<"offset">>, QS, 0),

    InfoFields = [registered_name, initial_call, current_function,
                  memory, reductions, message_queue_len, status],
    AllProcs = erlang:processes(),
    Total = length(AllProcs),

    %% Collect info for all processes, filter out dead ones
    WithInfo = lists:filtermap(fun(Pid) ->
        case erlang:process_info(Pid, InfoFields) of
            undefined -> false;
            Info -> {true, {Pid, Info}}
        end
    end, AllProcs),

    %% Sort
    Sorted = lists:sort(fun({_, A}, {_, B}) ->
        ValA = proplists:get_value(SortField, A, 0),
        ValB = proplists:get_value(SortField, B, 0),
        ValA >= ValB
    end, WithInfo),

    %% Paginate
    Page = lists:sublist(safe_drop(Sorted, Offset), Limit),

    Items = [format_process(Pid, Info) || {Pid, Info} <- Page],
    hecate_api_utils:json_ok(#{items => Items, total => Total,
                               limit => Limit, offset => Offset}, Req0).

format_process(Pid, Info) ->
    #{
        pid => format_pid(Pid),
        registered_name => format_name(proplists:get_value(registered_name, Info)),
        initial_call => format_mfa(proplists:get_value(initial_call, Info)),
        current_function => format_mfa(proplists:get_value(current_function, Info)),
        memory => proplists:get_value(memory, Info, 0),
        reductions => proplists:get_value(reductions, Info, 0),
        message_queue_len => proplists:get_value(message_queue_len, Info, 0),
        status => atom_to_binary(proplists:get_value(status, Info, unknown))
    }.

format_pid(Pid) ->
    %% Convert <0.123.0> to "0.123.0"
    PidStr = pid_to_list(Pid),
    list_to_binary(string:trim(PidStr, both, "<>")).

format_name([]) -> null;
format_name(undefined) -> null;
format_name(Name) when is_atom(Name) -> atom_to_binary(Name);
format_name(_) -> null.

format_mfa({M, F, A}) ->
    iolist_to_binary(io_lib:format("~s:~s/~B", [M, F, A]));
format_mfa(_) -> null.

qs_atom(Key, QS, Default) ->
    case proplists:get_value(Key, QS) of
        undefined -> Default;
        Bin -> binary_to_existing_atom(Bin)
    end.

qs_int(Key, QS, Default) ->
    case proplists:get_value(Key, QS) of
        undefined -> Default;
        Bin -> binary_to_integer(Bin)
    end.

safe_drop(List, 0) -> List;
safe_drop(List, N) when N >= length(List) -> [];
safe_drop(List, N) -> lists:nthtail(N, List).
