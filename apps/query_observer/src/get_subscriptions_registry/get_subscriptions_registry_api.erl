%%% @doc GET /api/observer/subscriptions — Handler registry.
%%%
%%% Shows which evoq_event_handler processes are alive and what
%%% event types they are registered for via pg groups.
%%% @end
-module(get_subscriptions_registry_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/subscriptions", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Groups = try pg:which_groups(pg)
             catch _:_ -> []
             end,
    %% Filter for event-type-like groups and collect member info
    Items = lists:filtermap(fun(Group) ->
        Members = try pg:get_members(pg, Group)
                  catch _:_ -> []
                  end,
        case Members of
            [] -> false;
            _ ->
                MemberInfos = [format_member(M) || M <- Members],
                {true, #{
                    group => format_group(Group),
                    member_count => length(Members),
                    members => MemberInfos
                }}
        end
    end, Groups),
    hecate_api_utils:json_ok(#{items => Items, total => length(Items)}, Req0).

format_member(Pid) when is_pid(Pid) ->
    Info = try erlang:process_info(Pid, [registered_name, initial_call]) of
        undefined -> [];
        I -> I
    catch _:_ -> []
    end,
    #{
        pid => format_pid(Pid),
        alive => is_process_alive(Pid),
        registered_name => format_name(proplists:get_value(registered_name, Info)),
        initial_call => format_mfa(proplists:get_value(initial_call, Info))
    };
format_member(Other) ->
    #{pid => format_term(Other), alive => false,
      registered_name => null, initial_call => null}.

format_pid(Pid) when is_pid(Pid) ->
    PidStr = pid_to_list(Pid),
    list_to_binary(string:trim(PidStr, both, "<>"));
format_pid(_) -> null.

format_name([]) -> null;
format_name(undefined) -> null;
format_name(Name) when is_atom(Name) -> atom_to_binary(Name);
format_name(_) -> null.

format_mfa({M, F, A}) ->
    iolist_to_binary(io_lib:format("~s:~s/~B", [M, F, A]));
format_mfa(_) -> null.

format_group(G) when is_atom(G) -> atom_to_binary(G);
format_group(G) when is_binary(G) -> G;
format_group(G) -> iolist_to_binary(io_lib:format("~p", [G])).

format_term(Term) ->
    iolist_to_binary(io_lib:format("~P", [Term, 20])).
