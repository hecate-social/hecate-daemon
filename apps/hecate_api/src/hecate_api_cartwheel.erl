%%% @doc Cartwheel API endpoints.
%%%
%%% Provides REST interface to Cartwheel management (bounded contexts):
%%% - GET  /api/cartwheel                     - Get active cartwheel (from current torch)
%%% - GET  /api/cartwheels                    - List all cartwheels
%%% - GET  /api/cartwheels/:cartwheel_id      - Get specific cartwheel by ID
%%%
%%% Also handles legacy ALC (Application Lifecycle) routes for backward compatibility.
%%%
%%% @end
-module(hecate_api_cartwheel).

-export([init/2]).

%% Route: GET /api/cartwheel
init(Req0, [get_active]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get_active(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/cartwheels (and POST /alc/projects for list)
init(Req0, [list]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_list(Req0);
        <<"POST">> ->
            %% Legacy: POST /alc/projects was for initiate
            handle_initiate(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: POST /alc/projects/initiate
init(Req0, [initiate]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_initiate(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/cartwheels/:cartwheel_id (and GET /alc/projects/:cartwheel_id)
init(Req0, [get]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get_by_id(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% ===================================================================
%% ALC Legacy Routes - Discovery & Analysis Phase
%% ===================================================================

%% POST /alc/projects/:cartwheel_id/discovery/start
init(Req0, [discovery_start]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, start_discovery_v1, maybe_start_discovery, #{cartwheel_id => CartwheelId});

%% POST /alc/projects/:cartwheel_id/discovery/findings/record
init(Req0, [discovery_finding]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        title => maps:get(<<"title">>, Params),
        category => maps:get(<<"category">>, Params, <<"requirement">>),
        content => maps:get(<<"content">>, Params, undefined),
        priority => maps:get(<<"priority">>, Params, <<"should">>)
    },
    dispatch_simple_cmd(Req1, record_finding_v1, maybe_record_finding, CmdParams);

%% GET /alc/projects/:cartwheel_id/discovery/findings
init(Req0, [discovery_list_findings]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_findings:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Findings} ->
            json_response(Req0, 200, #{ok => true, findings => Findings});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/discovery/terms/define
init(Req0, [discovery_term]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        term => maps:get(<<"term">>, Params),
        definition => maps:get(<<"definition">>, Params)
    },
    dispatch_simple_cmd(Req1, define_term_v1, maybe_define_term, CmdParams);

%% GET /alc/projects/:cartwheel_id/discovery/terms
init(Req0, [discovery_list_terms]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    case list_terms:execute(#{cartwheel_id => CartwheelId}) of
        {ok, Terms} ->
            json_response(Req0, 200, #{ok => true, terms => Terms});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/discovery/complete
init(Req0, [discovery_complete]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, complete_discovery_v1, maybe_complete_discovery, #{cartwheel_id => CartwheelId});

%% ===================================================================
%% ALC Legacy Routes - Phase Transition
%% ===================================================================

%% POST /alc/projects/:cartwheel_id/transition
init(Req0, [transition_phase]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        from_phase => maps:get(<<"from_phase">>, Params),
        to_phase => maps:get(<<"to_phase">>, Params)
    },
    dispatch_simple_cmd(Req1, transition_phase_v1, maybe_transition_phase, CmdParams);

%% ===================================================================
%% ALC Legacy Routes - Architecture & Planning Phase
%% ===================================================================

%% POST /alc/projects/:cartwheel_id/architecture/start
init(Req0, [architecture_start]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, start_architecture_v1, maybe_start_architecture, #{cartwheel_id => CartwheelId});

%% POST /alc/projects/:cartwheel_id/architecture/dossiers/define
init(Req0, [architecture_dossier]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        dossier_name => maps:get(<<"dossier_name">>, Params),
        stream_pattern => maps:get(<<"stream_pattern">>, Params, <<"default">>),
        description => maps:get(<<"description">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, define_dossier_v1, maybe_define_dossier, CmdParams);

%% GET /alc/projects/:cartwheel_id/architecture/dossiers
init(Req0, [architecture_list_dossiers]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_dossier_designs:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Dossiers} ->
            json_response(Req0, 200, #{ok => true, dossiers => Dossiers});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/architecture/spokes/inventory
init(Req0, [architecture_spoke]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        spoke_name => maps:get(<<"spoke_name">>, Params),
        spoke_type => maps:get(<<"spoke_type">>, Params),
        priority => maps:get(<<"priority">>, Params, <<"should">>),
        dossier_id => maps:get(<<"dossier_id">>, Params),
        description => maps:get(<<"description">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, inventory_spoke_v1, maybe_inventory_spoke, CmdParams);

%% GET /alc/projects/:cartwheel_id/architecture/spokes
init(Req0, [architecture_list_spokes]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_spoke_inventory:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Spokes} ->
            json_response(Req0, 200, #{ok => true, spokes => Spokes});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/architecture/plan
init(Req0, [architecture_plan]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        title => maps:get(<<"title">>, Params),
        content_ref => maps:get(<<"content_ref">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, draft_plan_v1, maybe_draft_plan, CmdParams);

%% POST /alc/projects/:cartwheel_id/architecture/plan/approve
init(Req0, [architecture_approve_plan]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        plan_id => maps:get(<<"plan_id">>, Params)
    },
    dispatch_simple_cmd(Req1, approve_plan_v1, maybe_approve_plan, CmdParams);

%% POST /alc/projects/:cartwheel_id/architecture/complete
init(Req0, [architecture_complete]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, complete_architecture_v1, maybe_complete_architecture, #{cartwheel_id => CartwheelId});

%% ===================================================================
%% ALC Legacy Routes - Testing & Implementation Phase
%% ===================================================================

%% POST /alc/projects/:cartwheel_id/testing/start
init(Req0, [testing_start]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, start_testing_v1, maybe_start_testing, #{cartwheel_id => CartwheelId});

%% POST /alc/projects/:cartwheel_id/testing/skeleton
init(Req0, [testing_skeleton]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        description => maps:get(<<"description">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, create_skeleton_v1, maybe_create_skeleton, CmdParams);

%% POST /alc/projects/:cartwheel_id/testing/implement
init(Req0, [testing_implement_spoke]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        spoke_id => maps:get(<<"spoke_id">>, Params),
        implementation_notes => maps:get(<<"implementation_notes">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, implement_spoke_v1, maybe_implement_spoke, CmdParams);

%% GET /alc/projects/:cartwheel_id/testing/implementations
init(Req0, [testing_list_implementations]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_spoke_implementations:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Implementations} ->
            json_response(Req0, 200, #{ok => true, implementations => Implementations});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/testing/verify
init(Req0, [testing_verify_build]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        result => maps:get(<<"result">>, Params, <<"pass">>),
        notes => maps:get(<<"notes">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, verify_build_v1, maybe_verify_build, CmdParams);

%% GET /alc/projects/:cartwheel_id/testing/builds
init(Req0, [testing_list_builds]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_build_verifications:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Builds} ->
            json_response(Req0, 200, #{ok => true, builds => Builds});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/testing/complete
init(Req0, [testing_complete]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, complete_testing_v1, maybe_complete_testing, #{cartwheel_id => CartwheelId});

%% ===================================================================
%% ALC Legacy Routes - Deployment & Operations Phase
%% ===================================================================

%% POST /alc/projects/:cartwheel_id/deployment/start
init(Req0, [deployment_start]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, start_deployment_v1, maybe_start_deployment, #{cartwheel_id => CartwheelId});

%% POST /alc/projects/:cartwheel_id/deployment/record
init(Req0, [deployment_record]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        environment => maps:get(<<"environment">>, Params),
        version => maps:get(<<"version">>, Params),
        notes => maps:get(<<"notes">>, Params, undefined)
    },
    dispatch_simple_cmd(Req1, record_deployment_v1, maybe_record_deployment, CmdParams);

%% GET /alc/projects/:cartwheel_id/deployment/deployments
init(Req0, [deployment_list_deployments]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_deployments:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Deployments} ->
            json_response(Req0, 200, #{ok => true, deployments => Deployments});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/deployment/incident
init(Req0, [deployment_report_incident]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        severity => maps:get(<<"severity">>, Params, <<"medium">>),
        description => maps:get(<<"description">>, Params)
    },
    dispatch_simple_cmd(Req1, report_incident_v1, maybe_report_incident, CmdParams);

%% POST /alc/projects/:cartwheel_id/deployment/incident/resolve
init(Req0, [deployment_resolve_incident]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        incident_id => maps:get(<<"incident_id">>, Params),
        resolution => maps:get(<<"resolution">>, Params)
    },
    dispatch_simple_cmd(Req1, resolve_incident_v1, maybe_resolve_incident, CmdParams);

%% GET /alc/projects/:cartwheel_id/deployment/incidents
init(Req0, [deployment_list_incidents]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_incidents:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Incidents} ->
            json_response(Req0, 200, #{ok => true, incidents => Incidents});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end;

%% POST /alc/projects/:cartwheel_id/deployment/complete
init(Req0, [deployment_complete]) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    dispatch_simple_cmd(Req0, complete_deployment_v1, maybe_complete_deployment, #{cartwheel_id => CartwheelId});

%% Catch-all
init(Req0, _State) ->
    not_found(Req0).

%%% ===================================================================
%%% Handlers
%%% ===================================================================

%% @doc Get active cartwheel from current torch.
handle_get_active(Req0) ->
    %% First get the active torch
    case list_torches:execute(#{limit => 1}) of
        {ok, [#{active_cartwheel_id := CartwheelId}]} when CartwheelId =/= undefined, CartwheelId =/= null ->
            %% Get the active cartwheel
            case get_cartwheel:execute(CartwheelId) of
                {ok, Cartwheel} ->
                    json_response(Req0, 200, #{ok => true, cartwheel => Cartwheel});
                {error, not_found} ->
                    json_response(Req0, 200, #{ok => true, cartwheel => null});
                {error, Reason} ->
                    error_response(Req0, 500, Reason)
            end;
        {ok, [_Torch]} ->
            %% Torch exists but no active cartwheel
            json_response(Req0, 200, #{ok => true, cartwheel => null});
        {ok, []} ->
            %% No torches
            json_response(Req0, 200, #{ok => true, cartwheel => null});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% @doc List all cartwheels.
handle_list(Req0) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_cartwheels:execute(Filters) of
        {ok, Cartwheels} ->
            json_response(Req0, 200, #{ok => true, cartwheels => Cartwheels});
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% @doc Get cartwheel by ID.
handle_get_by_id(Req0) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    case get_cartwheel:execute(CartwheelId) of
        {ok, Cartwheel} ->
            json_response(Req0, 200, #{ok => true, cartwheel => Cartwheel});
        {error, not_found} ->
            error_response(Req0, 404, <<"Cartwheel not found">>);
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% @doc Initiate a new cartwheel.
handle_initiate(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CmdParams = #{
        context_name => maps:get(<<"name">>, Params, maps:get(<<"context_name">>, Params, undefined)),
        torch_id => maps:get(<<"torch_id">>, Params, undefined),
        description => maps:get(<<"description">>, Params, undefined)
    },
    case initiate_cartwheel_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_initiate_cartwheel:dispatch(Cmd) of
                {ok, Version, Events} ->
                    json_response(Req1, 201, #{
                        ok => true,
                        version => Version,
                        events => Events,
                        cartwheel_id => initiate_cartwheel_v1:get_cartwheel_id(Cmd)
                    });
                {error, Reason} ->
                    error_response(Req1, 400, Reason)
            end;
        {error, Reason} ->
            error_response(Req1, 400, Reason)
    end.

%%% ===================================================================
%%% Internal helpers
%%% ===================================================================

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
            <<"torch_id">> -> Acc#{torch_id => V};
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
error_response(Req, StatusCode, Reason) when is_binary(Reason) ->
    Response = json:encode(#{ok => false, error => Reason}),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response, Req),
    {ok, Req2, []};
error_response(Req, StatusCode, Reason) ->
    ErrorBin = iolist_to_binary(io_lib:format("~p", [Reason])),
    error_response(Req, StatusCode, ErrorBin).

method_not_allowed(Req0) ->
    error_response(Req0, 405, <<"Method not allowed">>).

not_found(Req0) ->
    error_response(Req0, 404, <<"Not found">>).
