%%% @doc REST handler for Application Lifecycle (ALC) endpoints.
%%% Phase 1: Orchestration + Discovery & Analysis
%%% Phase 2: Architecture & Planning (AnP) + Phase Transition
%%% Phase 3: Testing & Implementation (TnI)
%%% Phase 4: Deployment & Operations (DnO)
-module(hecate_api_alc).

-export([init/2]).

%% Orchestration
init(Req0, [initiate]) ->
    handle_initiate(Req0);
init(Req0, [list_projects]) ->
    handle_list_projects(Req0);
init(Req0, [get_project]) ->
    handle_get_project(Req0);

%% Discovery & Analysis
init(Req0, [discovery_start]) ->
    handle_discovery_start(Req0);
init(Req0, [discovery_finding]) ->
    handle_discovery_finding(Req0);
init(Req0, [discovery_list_findings]) ->
    handle_discovery_list_findings(Req0);
init(Req0, [discovery_term]) ->
    handle_discovery_term(Req0);
init(Req0, [discovery_list_terms]) ->
    handle_discovery_list_terms(Req0);
init(Req0, [discovery_complete]) ->
    handle_discovery_complete(Req0);

%% Orchestration: Phase Transition
init(Req0, [transition_phase]) ->
    handle_transition_phase(Req0);

%% Architecture & Planning
init(Req0, [architecture_start]) ->
    handle_architecture_start(Req0);
init(Req0, [architecture_dossier]) ->
    handle_architecture_dossier(Req0);
init(Req0, [architecture_list_dossiers]) ->
    handle_architecture_list_dossiers(Req0);
init(Req0, [architecture_spoke]) ->
    handle_architecture_spoke(Req0);
init(Req0, [architecture_list_spokes]) ->
    handle_architecture_list_spokes(Req0);
init(Req0, [architecture_plan]) ->
    handle_architecture_plan(Req0);
init(Req0, [architecture_approve_plan]) ->
    handle_architecture_approve_plan(Req0);
init(Req0, [architecture_complete]) ->
    handle_architecture_complete(Req0);

%% Testing & Implementation
init(Req0, [testing_start]) ->
    handle_testing_start(Req0);
init(Req0, [testing_skeleton]) ->
    handle_testing_skeleton(Req0);
init(Req0, [testing_implement_spoke]) ->
    handle_testing_implement_spoke(Req0);
init(Req0, [testing_list_implementations]) ->
    handle_testing_list_implementations(Req0);
init(Req0, [testing_verify_build]) ->
    handle_testing_verify_build(Req0);
init(Req0, [testing_list_builds]) ->
    handle_testing_list_builds(Req0);
init(Req0, [testing_complete]) ->
    handle_testing_complete(Req0);

%% Deployment & Operations
init(Req0, [deployment_start]) ->
    handle_deployment_start(Req0);
init(Req0, [deployment_record]) ->
    handle_deployment_record(Req0);
init(Req0, [deployment_list_deployments]) ->
    handle_deployment_list_deployments(Req0);
init(Req0, [deployment_report_incident]) ->
    handle_deployment_report_incident(Req0);
init(Req0, [deployment_resolve_incident]) ->
    handle_deployment_resolve_incident(Req0);
init(Req0, [deployment_list_incidents]) ->
    handle_deployment_list_incidents(Req0);
init(Req0, [deployment_complete]) ->
    handle_deployment_complete(Req0).

%% POST /alc/projects
handle_initiate(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        name => maps:get(<<"name">>, Params),
        description => maps:get(<<"description">>, Params, undefined)
    },
    case initiate_project_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_initiate_project:dispatch(Cmd) of
                {ok, Version, Events} ->
                    json_response(Req1, 201, #{
                        ok => true,
                        version => Version,
                        events => Events,
                        project_id => initiate_project_v1:get_project_id(Cmd)
                    });
                {error, Reason} ->
                    error_response(Req1, 400, Reason)
            end;
        {error, Reason} ->
            error_response(Req1, 400, Reason)
    end.

%% GET /alc/projects
handle_list_projects(Req0) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_projects:execute(Filters) of
        {ok, Projects} ->
            json_response(Req0, 200, #{ok => true, projects => Projects});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% GET /alc/projects/:project_id
handle_get_project(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    case get_project:execute(ProjectId) of
        {ok, Project} ->
            json_response(Req0, 200, #{ok => true, project => Project});
        {error, not_found} ->
            error_response(Req0, 404, <<"not_found">>);
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/discovery/start
handle_discovery_start(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, start_discovery_v1, maybe_start_discovery, #{project_id => ProjectId}).

%% POST /alc/projects/:project_id/discovery/findings
handle_discovery_finding(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        title => maps:get(<<"title">>, Params),
        category => maps:get(<<"category">>, Params, <<"requirement">>),
        content => maps:get(<<"content">>, Params, undefined),
        priority => maps:get(<<"priority">>, Params, <<"should">>)
    },
    dispatch_simple_cmd(Req1, record_finding_v1, maybe_record_finding, CmdParams).

%% GET /alc/projects/:project_id/discovery/findings
handle_discovery_list_findings(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_findings:execute(Filters#{project_id => ProjectId}) of
        {ok, Findings} ->
            json_response(Req0, 200, #{ok => true, findings => Findings});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/discovery/terms
handle_discovery_term(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        term => maps:get(<<"term">>, Params),
        definition => maps:get(<<"definition">>, Params)
    },
    dispatch_simple_cmd(Req1, define_term_v1, maybe_define_term, CmdParams).

%% GET /alc/projects/:project_id/discovery/terms
handle_discovery_list_terms(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    case list_terms:execute(#{project_id => ProjectId}) of
        {ok, Terms} ->
            json_response(Req0, 200, #{ok => true, terms => Terms});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/discovery/complete
handle_discovery_complete(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, complete_discovery_v1, maybe_complete_discovery, #{project_id => ProjectId}).

%% POST /alc/projects/:project_id/transition
handle_transition_phase(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        from_phase => maps:get(<<"from_phase">>, Params),
        to_phase => maps:get(<<"to_phase">>, Params)
    },
    dispatch_simple_cmd(Req1, transition_phase_v1, maybe_transition_phase, CmdParams).

%% POST /alc/projects/:project_id/architecture/start
handle_architecture_start(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, start_architecture_v1, maybe_start_architecture, #{project_id => ProjectId}).

%% POST /alc/projects/:project_id/architecture/dossiers
handle_architecture_dossier(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        dossier_name => maps:get(<<"dossier_name">>, Params),
        stream_pattern => maps:get(<<"stream_pattern">>, Params, <<"default">>),
        description => maps:get(<<"description">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, define_dossier_v1, maybe_define_dossier, CmdParams).

%% GET /alc/projects/:project_id/architecture/dossiers
handle_architecture_list_dossiers(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_dossier_designs:execute(Filters#{project_id => ProjectId}) of
        {ok, Dossiers} ->
            json_response(Req0, 200, #{ok => true, dossiers => Dossiers});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/architecture/spokes
handle_architecture_spoke(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        spoke_name => maps:get(<<"spoke_name">>, Params),
        spoke_type => maps:get(<<"spoke_type">>, Params),
        priority => maps:get(<<"priority">>, Params, <<"should">>),
        dossier_id => maps:get(<<"dossier_id">>, Params),
        description => maps:get(<<"description">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, inventory_spoke_v1, maybe_inventory_spoke, CmdParams).

%% GET /alc/projects/:project_id/architecture/spokes
handle_architecture_list_spokes(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_spoke_inventory:execute(Filters#{project_id => ProjectId}) of
        {ok, Spokes} ->
            json_response(Req0, 200, #{ok => true, spokes => Spokes});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/architecture/plan
handle_architecture_plan(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        title => maps:get(<<"title">>, Params),
        content_ref => maps:get(<<"content_ref">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, draft_plan_v1, maybe_draft_plan, CmdParams).

%% POST /alc/projects/:project_id/architecture/plan/approve
handle_architecture_approve_plan(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        plan_id => maps:get(<<"plan_id">>, Params)
    },
    dispatch_simple_cmd(Req1, approve_plan_v1, maybe_approve_plan, CmdParams).

%% POST /alc/projects/:project_id/architecture/complete
handle_architecture_complete(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, complete_architecture_v1, maybe_complete_architecture, #{project_id => ProjectId}).

%% POST /alc/projects/:project_id/testing/start
handle_testing_start(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, start_testing_v1, maybe_start_testing, #{project_id => ProjectId}).

%% POST /alc/projects/:project_id/testing/skeleton
handle_testing_skeleton(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        description => maps:get(<<"description">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, create_skeleton_v1, maybe_create_skeleton, CmdParams).

%% POST /alc/projects/:project_id/testing/implement
handle_testing_implement_spoke(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        spoke_id => maps:get(<<"spoke_id">>, Params),
        implementation_notes => maps:get(<<"implementation_notes">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, implement_spoke_v1, maybe_implement_spoke, CmdParams).

%% GET /alc/projects/:project_id/testing/implementations
handle_testing_list_implementations(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_spoke_implementations:execute(Filters#{project_id => ProjectId}) of
        {ok, Implementations} ->
            json_response(Req0, 200, #{ok => true, implementations => Implementations});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/testing/verify
handle_testing_verify_build(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        result => maps:get(<<"result">>, Params, <<"pass">>),
        notes => maps:get(<<"notes">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, verify_build_v1, maybe_verify_build, CmdParams).

%% GET /alc/projects/:project_id/testing/builds
handle_testing_list_builds(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_build_verifications:execute(Filters#{project_id => ProjectId}) of
        {ok, Builds} ->
            json_response(Req0, 200, #{ok => true, builds => Builds});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/testing/complete
handle_testing_complete(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, complete_testing_v1, maybe_complete_testing, #{project_id => ProjectId}).

%% POST /alc/projects/:project_id/deployment/start
handle_deployment_start(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, start_deployment_v1, maybe_start_deployment, #{project_id => ProjectId}).

%% POST /alc/projects/:project_id/deployment/record
handle_deployment_record(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        environment => maps:get(<<"environment">>, Params),
        version => maps:get(<<"version">>, Params),
        notes => maps:get(<<"notes">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, record_deployment_v1, maybe_record_deployment, CmdParams).

%% GET /alc/projects/:project_id/deployment/deployments
handle_deployment_list_deployments(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_deployments:execute(Filters#{project_id => ProjectId}) of
        {ok, Deployments} ->
            json_response(Req0, 200, #{ok => true, deployments => Deployments});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/deployment/incident
handle_deployment_report_incident(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        severity => maps:get(<<"severity">>, Params, <<"medium">>),
        description => maps:get(<<"description">>, Params)
    },
    dispatch_simple_cmd(Req1, report_incident_v1, maybe_report_incident, CmdParams).

%% POST /alc/projects/:project_id/deployment/incident/resolve
handle_deployment_resolve_incident(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        project_id => ProjectId,
        incident_id => maps:get(<<"incident_id">>, Params),
        resolution => maps:get(<<"resolution">>, Params)
    },
    dispatch_simple_cmd(Req1, resolve_incident_v1, maybe_resolve_incident, CmdParams).

%% GET /alc/projects/:project_id/deployment/incidents
handle_deployment_list_incidents(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_incidents:execute(Filters#{project_id => ProjectId}) of
        {ok, Incidents} ->
            json_response(Req0, 200, #{ok => true, incidents => Incidents});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% POST /alc/projects/:project_id/deployment/complete
handle_deployment_complete(Req0) ->
    ProjectId = cowboy_req:binding(project_id, Req0),
    dispatch_simple_cmd(Req0, complete_deployment_v1, maybe_complete_deployment, #{project_id => ProjectId}).

%% Internal helpers

dispatch_simple_cmd(Req, CmdMod, HandlerMod, CmdParams) ->
    case CmdMod:new(CmdParams) of
        {ok, Cmd} ->
            case HandlerMod:dispatch(Cmd) of
                {ok, Version, Events} ->
                    json_response(Req, 200, #{
                        ok => true,
                        version => Version,
                        events => Events
                    });
                {error, Reason} ->
                    error_response(Req, 400, Reason)
            end;
        {error, Reason} ->
            error_response(Req, 400, Reason)
    end.

build_filters(QS) ->
    lists:foldl(fun({K, V}, Acc) ->
        case K of
            <<"category">> -> Acc#{category => V};
            <<"priority">> -> Acc#{priority => V};
            <<"dossier_id">> -> Acc#{dossier_id => V};
            <<"spoke_id">> -> Acc#{spoke_id => V};
            <<"severity">> -> Acc#{severity => V};
            <<"current_phase">> -> Acc#{current_phase => V};
            <<"status">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{status_mask => I};
                    _ -> Acc
                end;
            <<"limit">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{limit => I};
                    _ -> Acc
                end;
            <<"offset">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{offset => I};
                    _ -> Acc
                end;
            _ -> Acc
        end
    end, #{}, QS).

json_response(Req, StatusCode, Data) ->
    Response = json:encode(Data),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req),
    {ok, Req2, []}.

error_response(Req, StatusCode, Reason) when is_atom(Reason) ->
    error_response(Req, StatusCode, atom_to_binary(Reason, utf8));
error_response(Req, StatusCode, Reason) ->
    Response = json:encode(#{ok => false, error => Reason}),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req),
    {ok, Req2, []}.
