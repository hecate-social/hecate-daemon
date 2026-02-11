-module(get_venture_tasks).
-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found}.
execute(VentureId) ->
    case venture_state:get_venture_status(VentureId) of
        {ok, Status} ->
            {ok, build_task_list(Status)};
        {error, not_found} ->
            {error, not_found}
    end.

%% Build the full task list response from venture status data.
build_task_list(#{venture_id := VentureId, name := Name, phase := Phase,
                  status := VStatus} = Status) ->
    Divisions = maps:get(divisions, Status, []),
    #{
        venture => #{
            id => VentureId,
            name => Name,
            status => atom_to_binary(VStatus)
        },
        tasks => venture_tasks(Phase),
        divisions => [division_tasks(Div) || Div <- Divisions]
    }.

%% Derive venture-level task states from the current phase.
%%
%% Phase progression: setup → discovery → designing → (division phases)
%%
%% Task ordering:
%%   1. initiate-venture — always done once we have a venture record
%%   2. refine-vision    — DnA phase, active during setup
%%   3. submit-vision    — completes DnA, active after refine
%%   4. refine-divisions — active during discovery
venture_tasks(setup) ->
    [
        vtask(<<"initiate-venture">>, <<"setup">>, <<>>,      <<"done">>),
        vtask(<<"refine-vision">>,    <<"DnA">>,   <<"DnA">>, <<"active">>),
        vtask(<<"submit-vision">>,    <<"DnA">>,   <<>>,      <<"blocked">>),
        vtask(<<"refine-divisions">>, <<"DnA">>,   <<"DnA">>, <<"blocked">>)
    ];
venture_tasks(discovery) ->
    [
        vtask(<<"initiate-venture">>, <<"setup">>, <<>>,      <<"done">>),
        vtask(<<"refine-vision">>,    <<"DnA">>,   <<"DnA">>, <<"done">>),
        vtask(<<"submit-vision">>,    <<"DnA">>,   <<>>,      <<"done">>),
        vtask(<<"refine-divisions">>, <<"DnA">>,   <<"DnA">>, <<"active">>)
    ];
venture_tasks(_Later) ->
    %% designing, planning, generating, testing, deploying, monitoring, rescuing
    [
        vtask(<<"initiate-venture">>, <<"setup">>, <<>>,      <<"done">>),
        vtask(<<"refine-vision">>,    <<"DnA">>,   <<"DnA">>, <<"done">>),
        vtask(<<"submit-vision">>,    <<"DnA">>,   <<>>,      <<"done">>),
        vtask(<<"refine-divisions">>, <<"DnA">>,   <<"DnA">>, <<"done">>)
    ].

vtask(Verb, Phase, AIRole, State) ->
    #{
        verb => Verb,
        scope => <<"venture">>,
        state => State,
        phase => Phase,
        ai_role => AIRole
    }.

%% Build per-division task list from the processes map.
division_tasks(#{division_id := DivId, name := Name, processes := Processes}) ->
    #{
        id => DivId,
        name => Name,
        tasks => [
            dtask(<<"design">>,  <<"AnP">>, <<"AnP">>, process_state(design, Processes)),
            dtask(<<"plan">>,    <<"AnP">>, <<"AnP">>, process_state(plan, Processes)),
            dtask(<<"generate">>,<<"TnI">>, <<"TnI">>, process_state(generation, Processes, design, plan)),
            dtask(<<"test">>,    <<"TnI">>, <<"TnI">>, process_state(testing, Processes, generation)),
            dtask(<<"deploy">>,  <<"DnO">>, <<"DnO">>, process_state(deployment, Processes, testing)),
            dtask(<<"monitor">>, <<"DnO">>, <<"DnO">>, process_state(monitoring, Processes, deployment)),
            dtask(<<"rescue">>,  <<"DnO">>, <<"DnO">>, rescue_state(Processes))
        ]
    }.

dtask(Verb, Phase, AIRole, State) ->
    #{
        verb => Verb,
        state => State,
        phase => Phase,
        ai_role => AIRole
    }.

%% Simple process state: design and plan have no prerequisites (except design blocks plan).
process_state(design, Processes) ->
    map_process_value(maps:get(design, Processes, pending));
process_state(plan, Processes) ->
    case maps:get(design, Processes, pending) of
        completed -> map_process_value(maps:get(plan, Processes, pending));
        _ ->
            case maps:get(plan, Processes, pending) of
                pending -> <<"blocked">>;
                Other -> map_process_value(Other)
            end
    end.

%% Process state with a single prerequisite.
process_state(Process, Processes, Prereq) ->
    case maps:get(Prereq, Processes, pending) of
        completed -> map_process_value(maps:get(Process, Processes, pending));
        _ ->
            case maps:get(Process, Processes, pending) of
                pending -> <<"blocked">>;
                Other -> map_process_value(Other)
            end
    end.

%% Process state with two prerequisites (both must be completed).
process_state(Process, Processes, Prereq1, Prereq2) ->
    P1 = maps:get(Prereq1, Processes, pending),
    P2 = maps:get(Prereq2, Processes, pending),
    case {P1, P2} of
        {completed, completed} -> map_process_value(maps:get(Process, Processes, pending));
        _ ->
            case maps:get(Process, Processes, pending) of
                pending -> <<"blocked">>;
                Other -> map_process_value(Other)
            end
    end.

%% Rescue is special: idle means no rescue needed (not blocked).
rescue_state(Processes) ->
    case maps:get(rescue, Processes, idle) of
        idle -> <<"pending">>;
        Other -> map_process_value(Other)
    end.

map_process_value(pending) -> <<"pending">>;
map_process_value(active) -> <<"active">>;
map_process_value(completed) -> <<"done">>;
map_process_value(paused) -> <<"paused">>;
map_process_value(idle) -> <<"pending">>;
map_process_value(_) -> <<"pending">>.
