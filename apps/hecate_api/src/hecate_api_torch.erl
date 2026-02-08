%%% @doc Torch API endpoints.
%%%
%%% Provides REST interface to Torch management (business endeavors):
%%% - GET  /api/torch                             - Get current/active torch
%%% - POST /api/torch/initiate                    - Initiate a new torch
%%% - GET  /api/torches                           - List all torches
%%% - GET  /api/torches/:torch_id                 - Get specific torch by ID
%%% - POST /api/torches/:torch_id/cartwheels/identify - Identify a cartwheel within a torch
%%%
%%% @end
-module(hecate_api_torch).

-export([init/2]).

%% Route: GET /api/torch
init(Req0, [get]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get_active(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: POST /api/torch/initiate
init(Req0, [initiate]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_initiate(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/torches
init(Req0, [list]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_list(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/torches/:torch_id
init(Req0, [get_by_id]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get_by_id(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: POST /api/torches/:torch_id/cartwheels/identify
init(Req0, [identify_cartwheel]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_identify_cartwheel(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

init(Req0, _State) ->
    not_found(Req0).

%%% ===================================================================
%%% Handlers
%%% ===================================================================

%% @doc Get current/active torch (returns first torch from list).
handle_get_active(Req0) ->
    case list_torches:execute(#{limit => 1}) of
        {ok, [Torch | _]} ->
            json_response(200, #{ok => true, torch => Torch}, Req0);
        {ok, []} ->
            json_response(200, #{ok => true, torch => null}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

%% @doc Initiate a new torch.
handle_initiate(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    try json:decode(Body) of
        Params ->
            Name = maps:get(<<"name">>, Params, undefined),
            Brief = maps:get(<<"brief">>, Params, undefined),
            InitiatedBy = maps:get(<<"initiated_by">>, Params, undefined),

            case validate_initiate_params(Name) of
                ok ->
                    CmdParams = #{
                        name => Name,
                        brief => Brief,
                        initiated_by => InitiatedBy
                    },
                    case initiate_torch_v1:new(CmdParams) of
                        {ok, Cmd} ->
                            case dispatch_torch_command(Cmd) of
                                {ok, Version, Events} ->
                                    json_response(201, #{
                                        ok => true,
                                        torch_id => initiate_torch_v1:get_torch_id(Cmd),
                                        version => Version,
                                        events => Events
                                    }, Req1);
                                {error, Reason} ->
                                    json_response(400, #{ok => false, error => format_error(Reason)}, Req1)
                            end;
                        {error, Reason} ->
                            json_response(400, #{ok => false, error => format_error(Reason)}, Req1)
                    end;
                {error, Reason} ->
                    json_response(400, #{ok => false, error => Reason}, Req1)
            end
    catch
        _:_ ->
            json_response(400, #{ok => false, error => <<"Invalid JSON">>}, Req1)
    end.

%% @doc List all torches.
handle_list(Req0) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_torches:execute(Filters) of
        {ok, Torches} ->
            json_response(200, #{ok => true, torches => Torches}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

%% @doc Get torch by ID.
handle_get_by_id(Req0) ->
    TorchId = cowboy_req:binding(torch_id, Req0),
    case get_torch:execute(TorchId) of
        {ok, Torch} ->
            json_response(200, #{ok => true, torch => Torch}, Req0);
        {error, not_found} ->
            json_response(404, #{ok => false, error => <<"Torch not found">>}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

%% @doc Identify a cartwheel within a torch.
%% This is the parent (torch) declaring "I need a cartwheel called X".
%% The cartwheel service will react to the mesh fact and initiate the cartwheel.
handle_identify_cartwheel(Req0) ->
    TorchId = cowboy_req:binding(torch_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    try json:decode(Body) of
        Params ->
            ContextName = maps:get(<<"context_name">>, Params, undefined),
            Description = maps:get(<<"description">>, Params, undefined),
            IdentifiedBy = maps:get(<<"identified_by">>, Params, undefined),

            case validate_identify_params(ContextName) of
                ok ->
                    CmdParams = #{
                        torch_id => TorchId,
                        context_name => ContextName,
                        description => Description,
                        identified_by => IdentifiedBy
                    },
                    case identify_cartwheel_v1:new(CmdParams) of
                        {ok, Cmd} ->
                            case dispatch_identify_cartwheel_command(Cmd) of
                                {ok, Version, Events} ->
                                    %% Extract cartwheel_id from first event
                                    CartwheelId = case Events of
                                        [#{<<"cartwheel_id">> := CId} | _] -> CId;
                                        _ -> undefined
                                    end,
                                    json_response(201, #{
                                        ok => true,
                                        torch_id => TorchId,
                                        cartwheel_id => CartwheelId,
                                        context_name => ContextName,
                                        version => Version,
                                        events => Events
                                    }, Req1);
                                {error, Reason} ->
                                    json_response(400, #{ok => false, error => format_error(Reason)}, Req1)
                            end;
                        {error, Reason} ->
                            json_response(400, #{ok => false, error => format_error(Reason)}, Req1)
                    end;
                {error, Reason} ->
                    json_response(400, #{ok => false, error => Reason}, Req1)
            end
    catch
        _:_ ->
            json_response(400, #{ok => false, error => <<"Invalid JSON">>}, Req1)
    end.

%%% ===================================================================
%%% Helpers
%%% ===================================================================

validate_initiate_params(undefined) ->
    {error, <<"name is required">>};
validate_initiate_params(Name) when not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, <<"name must be a non-empty string">>};
validate_initiate_params(_Name) ->
    ok.

validate_identify_params(undefined) ->
    {error, <<"context_name is required">>};
validate_identify_params(ContextName) when not is_binary(ContextName); byte_size(ContextName) =:= 0 ->
    {error, <<"context_name must be a non-empty string">>};
validate_identify_params(_ContextName) ->
    ok.

%% @doc Dispatch torch command via evoq (persists to ReckonDB).
dispatch_torch_command(Cmd) ->
    case maybe_initiate_torch:dispatch(Cmd) of
        {ok, Version, Events} ->
            %% Notify process manager(s) about torch initiated event
            notify_process_managers(Events),
            {ok, Version, Events};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Process events after successful dispatch.
%% 1. Emit to pg for internal integration (projections)
%% 2. Emit to mesh for external integration (cross-daemon)
notify_process_managers(EventMaps) ->
    logger:info("[API] notify_process_managers: ~p events", [length(EventMaps)]),
    lists:foreach(fun(EventMap) ->
        emit_torch_event(EventMap)
    end, EventMaps).

%% @doc Emit torch event to appropriate transports.
emit_torch_event(#{<<"event_type">> := <<"torch_initiated_v1">>} = Event) ->
    %% Convert binary keys to atoms for pg consumers
    AtomEvent = #{
        torch_id => maps:get(<<"torch_id">>, Event),
        name => maps:get(<<"name">>, Event),
        brief => maps:get(<<"brief">>, Event, undefined),
        initiated_at => maps:get(<<"initiated_at">>, Event),
        initiated_by => maps:get(<<"initiated_by">>, Event, undefined)
    },
    %% INTERNAL: Emit to pg for projections (intra-daemon)
    torch_initiated_v1_to_pg:emit(AtomEvent),
    %% EXTERNAL: Emit to mesh for other agents (WAN)
    torch_initiated_v1_to_mesh:emit(Event);
emit_torch_event(_Other) ->
    ok.

%% @doc Dispatch identify_cartwheel command.
%% After successful handling, emits the cartwheel_identified fact to mesh.
dispatch_identify_cartwheel_command(Cmd) ->
    case maybe_identify_cartwheel:handle(Cmd) of
        {ok, Events} ->
            EventMaps = [cartwheel_identified_v1:to_map(E) || E <- Events],
            %% Emit to mesh for manage_cartwheels to react
            lists:foreach(fun(EventMap) ->
                cartwheel_identified_v1_to_mesh:emit(EventMap)
            end, EventMaps),
            {ok, 0, EventMaps};
        {error, Reason} ->
            {error, Reason}
    end.

build_filters(QS) ->
    lists:foldl(fun({K, V}, Acc) ->
        case K of
            <<"status">> -> Acc#{status => V};
            <<"name">> -> Acc#{name => V};
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

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason);
format_error({Type, Details}) ->
    iolist_to_binary(io_lib:format("~p: ~p", [Type, Details]));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

json_response(StatusCode, Body, Req0) ->
    JsonBody = json:encode(Body),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, JsonBody, Req0),
    {ok, Req, []}.

method_not_allowed(Req0) ->
    json_response(405, #{ok => false, error => <<"Method not allowed">>}, Req0).

not_found(Req0) ->
    json_response(404, #{ok => false, error => <<"Not found">>}, Req0).
