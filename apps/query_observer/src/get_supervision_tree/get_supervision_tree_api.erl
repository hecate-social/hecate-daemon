%%% @doc GET /api/observer/supervision — Supervision tree.
%%%
%%% Recursive tree of supervisors and workers.
%%% Query params: root=hecate_sup (default), max_depth=10
%%% @end
-module(get_supervision_tree_api).

-export([init/2, routes/0]).

-define(MAX_DEPTH, 10).

routes() -> [{"/api/observer/supervision", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    RootName = case proplists:get_value(<<"root">>, QS) of
        undefined -> hecate_sup;
        Bin -> binary_to_existing_atom(Bin)
    end,
    MaxDepth = qs_int(<<"max_depth">>, QS, ?MAX_DEPTH),
    case whereis(RootName) of
        undefined ->
            hecate_api_utils:not_found(Req0);
        Pid ->
            Tree = build_tree(RootName, Pid, supervisor, MaxDepth),
            hecate_api_utils:json_ok(#{tree => Tree}, Req0)
    end.

build_tree(Id, Pid, Type, Depth) ->
    Base = #{
        id => format_id(Id),
        pid => format_pid(Pid),
        type => atom_to_binary(Type),
        status => process_status(Pid)
    },
    case Type of
        supervisor when Depth > 0 ->
            Children = get_children(Pid, Depth - 1),
            Base#{children => Children};
        _ ->
            Base#{children => []}
    end.

get_children(SupPid, RemainingDepth) ->
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
                            children => []
                        }};
                    _ when is_pid(Pid) ->
                        {true, build_tree(Id, Pid, Type, RemainingDepth)};
                    _ ->
                        false
                end
            end, Children)
    catch _:_ -> []
    end.

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

qs_int(Key, QS, Default) ->
    case proplists:get_value(Key, QS) of
        undefined -> Default;
        Bin -> binary_to_integer(Bin)
    end.
