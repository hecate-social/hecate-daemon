%%% @doc GET /api/observer/processes/:pid — Process detail.
%%%
%%% :pid format: 0.123.0 (no angle brackets).
%%% Returns extended process info including dictionary, links, monitors.
%%% @end
-module(get_process_by_pid_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/processes/:pid", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    PidBin = cowboy_req:binding(pid, Req0),
    case parse_pid(PidBin) of
        {ok, Pid} ->
            InfoFields = [registered_name, initial_call, current_function,
                          memory, reductions, message_queue_len, status,
                          links, monitors, trap_exit, heap_size,
                          stack_size, total_heap_size, dictionary,
                          garbage_collection, current_stacktrace],
            case erlang:process_info(Pid, InfoFields) of
                undefined ->
                    hecate_api_utils:not_found(Req0);
                Info ->
                    hecate_api_utils:json_ok(format_detail(Pid, Info), Req0)
            end;
        error ->
            hecate_api_utils:bad_request(<<"Invalid pid format. Expected: 0.123.0">>, Req0)
    end.

parse_pid(PidBin) ->
    PidStr = "<" ++ binary_to_list(PidBin) ++ ">",
    try
        {ok, list_to_pid(PidStr)}
    catch _:_ ->
        error
    end.

format_detail(Pid, Info) ->
    Dict = proplists:get_value(dictionary, Info, []),
    TruncDict = lists:sublist(Dict, 20),
    GC = proplists:get_value(garbage_collection, Info, []),
    Stack = proplists:get_value(current_stacktrace, Info, []),
    #{
        pid => format_pid(Pid),
        registered_name => format_name(proplists:get_value(registered_name, Info)),
        initial_call => format_mfa(proplists:get_value(initial_call, Info)),
        current_function => format_mfa(proplists:get_value(current_function, Info)),
        memory => proplists:get_value(memory, Info, 0),
        reductions => proplists:get_value(reductions, Info, 0),
        message_queue_len => proplists:get_value(message_queue_len, Info, 0),
        status => atom_to_binary(proplists:get_value(status, Info, unknown)),
        links => [format_pid_or_port(L) || L <- proplists:get_value(links, Info, [])],
        monitors => format_monitors(proplists:get_value(monitors, Info, [])),
        trap_exit => proplists:get_value(trap_exit, Info, false),
        heap_size => proplists:get_value(heap_size, Info, 0),
        stack_size => proplists:get_value(stack_size, Info, 0),
        total_heap_size => proplists:get_value(total_heap_size, Info, 0),
        dictionary => [#{key => format_term(K), value => format_term(V)}
                        || {K, V} <- TruncDict],
        dictionary_size => length(Dict),
        garbage_collection => #{
            minor_gcs => proplists:get_value(minor_gcs, GC, 0),
            fullsweep_after => proplists:get_value(fullsweep_after, GC, 0)
        },
        current_stacktrace => [format_stack_entry(S) || S <- Stack]
    }.

format_pid(Pid) ->
    PidStr = pid_to_list(Pid),
    list_to_binary(string:trim(PidStr, both, "<>")).

format_pid_or_port(Pid) when is_pid(Pid) -> format_pid(Pid);
format_pid_or_port(Port) when is_port(Port) ->
    list_to_binary(erlang:port_to_list(Port));
format_pid_or_port(Other) -> format_term(Other).

format_name([]) -> null;
format_name(undefined) -> null;
format_name(Name) when is_atom(Name) -> atom_to_binary(Name);
format_name(_) -> null.

format_mfa({M, F, A}) ->
    iolist_to_binary(io_lib:format("~s:~s/~B", [M, F, A]));
format_mfa(_) -> null.

format_monitors(Monitors) ->
    [format_monitor(M) || M <- Monitors].

format_monitor({process, Pid}) when is_pid(Pid) ->
    #{type => <<"process">>, target => format_pid(Pid)};
format_monitor({process, Name}) when is_atom(Name) ->
    #{type => <<"process">>, target => atom_to_binary(Name)};
format_monitor({process, {Name, Node}}) ->
    #{type => <<"process">>, target => format_term({Name, Node})};
format_monitor(Other) ->
    #{type => <<"other">>, target => format_term(Other)}.

format_stack_entry({M, F, A, Info}) ->
    Base = #{module => atom_to_binary(M), function => atom_to_binary(F), arity => A},
    case proplists:get_value(file, Info) of
        undefined -> Base;
        File ->
            Line = proplists:get_value(line, Info, 0),
            Base#{file => list_to_binary(File), line => Line}
    end;
format_stack_entry(Other) ->
    #{raw => format_term(Other)}.

format_term(Term) ->
    iolist_to_binary(io_lib:format("~P", [Term, 20])).
