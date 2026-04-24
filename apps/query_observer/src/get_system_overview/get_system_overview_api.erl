%%% @doc GET /api/observer/system — BEAM system overview.
%%%
%%% Returns memory, process counts, scheduler info, uptime,
%%% OTP release, boot phase, and pg groups.
%%% @end
-module(get_system_overview_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/system", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Memory = erlang:memory(),
    MemoryMap = #{
        total => proplists:get_value(total, Memory, 0),
        processes => proplists:get_value(processes, Memory, 0),
        system => proplists:get_value(system, Memory, 0),
        atom => proplists:get_value(atom, Memory, 0),
        binary => proplists:get_value(binary, Memory, 0),
        code => proplists:get_value(code, Memory, 0),
        ets => proplists:get_value(ets, Memory, 0)
    },
    ProcessCount = erlang:system_info(process_count),
    ProcessLimit = erlang:system_info(process_limit),
    SchedulersTotal = erlang:system_info(schedulers),
    SchedulersOnline = erlang:system_info(schedulers_online),
    AtomCount = erlang:system_info(atom_count),
    AtomLimit = erlang:system_info(atom_limit),
    PortCount = erlang:system_info(port_count),
    PortLimit = erlang:system_info(port_limit),
    {UptimeMs, _} = erlang:statistics(wall_clock),
    OtpRelease = list_to_binary(erlang:system_info(otp_release)),
    ErtsVersion = list_to_binary(erlang:system_info(version)),
    BootPhase = get_boot_phase(),
    PgGroups = get_pg_groups(),
    Response = #{
        memory => MemoryMap,
        processes => #{count => ProcessCount, limit => ProcessLimit},
        schedulers => #{total => SchedulersTotal, online => SchedulersOnline},
        atoms => #{count => AtomCount, limit => AtomLimit},
        ports => #{count => PortCount, limit => PortLimit},
        uptime_ms => UptimeMs,
        otp_release => OtpRelease,
        erts_version => ErtsVersion,
        boot_phase => BootPhase,
        pg_groups => PgGroups
    },
    hecate_api_utils:json_ok(Response, Req0).

get_boot_phase() ->
    try
        Status = boot_daemon:get_status(),
        maps:get(boot_phase, Status, <<"unknown">>)
    catch _:_ ->
        case hecate_lifecycle:get_state() of
            running -> <<"running">>;
            starting -> <<"starting">>;
            Other -> atom_to_binary(Other)
        end
    end.

get_pg_groups() ->
    try
        Groups = pg:which_groups(pg),
        [#{name => format_term(G), member_count => length(pg:get_members(pg, G))}
         || G <- Groups]
    catch _:_ -> []
    end.

format_term(Term) when is_atom(Term) ->
    atom_to_binary(Term);
format_term(Term) when is_binary(Term) ->
    Term;
format_term(Term) ->
    iolist_to_binary(io_lib:format("~p", [Term])).
