%%% @doc GET /api/observer/supervision/children — List direct children of a supervisor.
%%%
%%% Lazy supervision tree navigation: returns only ONE level of children.
%%% The frontend manages the navigation stack (ranger-style drill-down).
%%%
%%% Query params:
%%%   - pid: Erlang PID string (e.g., "0.1894.0") — required unless name is given
%%%   - name: Registered name (e.g., "hecate_sup") — alternative to pid
%%%
%%% Also supports: GET /api/observer/supervision/roots — list all OTP application supervisors
%%% @end
-module(get_supervision_children_api).

-export([init/2, routes/0]).

routes() ->
    [{"/api/observer/supervision/children", ?MODULE, []},
     {"/api/observer/supervision/roots", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            Path = cowboy_req:path(Req0),
            case binary:match(Path, <<"roots">>) of
                nomatch -> handle_children(Req0, State);
                _ -> handle_roots(Req0, State)
            end;
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

%% List all OTP application supervisors (top-level entry points)
handle_roots(Req0, _State) ->
    Apps = application:which_applications(),
    Roots = lists:filtermap(fun({App, _Desc, _Vsn}) ->
        %% Convention: app supervisor is {app_name}_sup
        SupName = list_to_atom(atom_to_list(App) ++ "_sup"),
        case whereis(SupName) of
            undefined -> false;
            Pid ->
                {true, #{
                    id => atom_to_binary(SupName),
                    pid => format_pid(Pid),
                    type => <<"supervisor">>,
                    status => process_status(Pid),
                    app => atom_to_binary(App),
                    child_count => count_children(Pid)
                }}
        end
    end, Apps),
    %% Sort by app name
    Sorted = lists:sort(fun(#{id := A}, #{id := B}) -> A =< B end, Roots),
    hecate_api_utils:json_ok(#{items => Sorted, total => length(Sorted)}, Req0).

%% List direct children of a specific supervisor
handle_children(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    case resolve_pid(QS) of
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req0);
        {ok, Pid} ->
            case is_supervisor(Pid) of
                false ->
                    %% Not a supervisor — return process info instead
                    Info = process_info_map(Pid),
                    hecate_api_utils:json_ok(#{type => <<"worker">>, info => Info, items => [], total => 0}, Req0);
                true ->
                    Children = get_children(Pid),
                    hecate_api_utils:json_ok(#{items => Children, total => length(Children)}, Req0)
            end
    end.

resolve_pid(QS) ->
    case proplists:get_value(<<"name">>, QS) of
        undefined ->
            case proplists:get_value(<<"pid">>, QS) of
                undefined ->
                    {error, <<"Missing 'pid' or 'name' parameter">>};
                PidBin ->
                    try
                        PidStr = "<" ++ binary_to_list(PidBin) ++ ">",
                        {ok, list_to_pid(PidStr)}
                    catch _:_ ->
                        {error, <<"Invalid pid format">>}
                    end
            end;
        NameBin ->
            try
                Atom = binary_to_existing_atom(NameBin),
                case whereis(Atom) of
                    undefined -> {error, <<"Process not found: ", NameBin/binary>>};
                    Pid -> {ok, Pid}
                end
            catch _:_ ->
                {error, <<"Unknown atom: ", NameBin/binary>>}
            end
    end.

get_children(SupPid) ->
    try supervisor:which_children(SupPid) of
        Children ->
            lists:filtermap(fun({Id, Pid, Type, _Mods}) ->
                case Pid of
                    undefined -> false;
                    restarting ->
                        {true, #{
                            id => format_id(Id),
                            pid => null,
                            type => atom_to_binary(Type),
                            status => <<"restarting">>,
                            child_count => 0
                        }};
                    _ when is_pid(Pid) ->
                        ChildCount = case Type of
                            supervisor -> count_children(Pid);
                            _ -> 0
                        end,
                        {true, #{
                            id => format_id(Id),
                            pid => format_pid(Pid),
                            type => atom_to_binary(Type),
                            status => process_status(Pid),
                            child_count => ChildCount
                        }};
                    _ ->
                        false
                end
            end, Children)
    catch _:_ -> []
    end.

count_children(SupPid) ->
    try
        Props = supervisor:count_children(SupPid),
        proplists:get_value(active, Props, 0)
    catch _:_ -> 0
    end.

is_supervisor(Pid) ->
    case erlang:process_info(Pid, dictionary) of
        {dictionary, Dict} ->
            case proplists:get_value('$initial_call', Dict) of
                {supervisor, _, _} -> true;
                _ -> false
            end;
        _ -> false
    end.

process_info_map(Pid) ->
    try
        Info = erlang:process_info(Pid, [
            registered_name, initial_call, current_function,
            memory, reductions, message_queue_len, status,
            heap_size, stack_size, total_heap_size, trap_exit
        ]),
        maps:from_list(lists:map(fun
            ({registered_name, []}) -> {registered_name, null};
            ({registered_name, Name}) -> {registered_name, atom_to_binary(Name)};
            ({initial_call, {M, F, A}}) -> {initial_call, format_mfa(M, F, A)};
            ({current_function, {M, F, A}}) -> {current_function, format_mfa(M, F, A)};
            ({status, S}) -> {status, atom_to_binary(S)};
            ({trap_exit, B}) -> {trap_exit, B};
            (KV) -> KV
        end, Info))
    catch _:_ -> #{}
    end.

format_mfa(M, F, A) ->
    iolist_to_binary([atom_to_list(M), $:, atom_to_list(F), $/, integer_to_list(A)]).

process_status(Pid) when is_pid(Pid) ->
    case erlang:process_info(Pid, status) of
        {status, Status} -> atom_to_binary(Status);
        undefined -> <<"dead">>
    end;
process_status(_) -> <<"unknown">>.

format_id(Id) when is_atom(Id) -> atom_to_binary(Id);
format_id(Id) -> iolist_to_binary(io_lib:format("~p", [Id])).

format_pid(Pid) when is_pid(Pid) ->
    PidStr = pid_to_list(Pid),
    list_to_binary(string:trim(PidStr, both, "<>"));
format_pid(_) -> null.
