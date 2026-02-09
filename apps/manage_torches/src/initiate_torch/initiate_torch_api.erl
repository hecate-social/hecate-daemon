%%% @doc API handler: POST /api/torch/initiate
%%%
%%% Initiates a new torch (business endeavor).
%%% Lives in the initiate_torch spoke for vertical slicing.
%%% @end
-module(initiate_torch_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_initiate(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_initiate(Params, Req) ->
    Name = hecate_api_utils:get_field(name, Params),
    Brief = hecate_api_utils:get_field(brief, Params),
    InitiatedBy = hecate_api_utils:get_field(initiated_by, Params),

    case validate(Name) of
        ok -> create_torch(Name, Brief, InitiatedBy, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined) -> {error, <<"name is required">>};
validate(Name) when not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, <<"name must be a non-empty string">>};
validate(_) -> ok.

create_torch(Name, Brief, InitiatedBy, Req) ->
    CmdParams = #{name => Name, brief => Brief, initiated_by => InitiatedBy},
    case initiate_torch_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_initiate_torch:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            %% INTERNAL: Emit to pg for projections (intra-daemon)
            emit_to_pg(EventMaps),
            %% EXTERNAL: Emit to mesh for other agents (WAN)
            emit_to_mesh(EventMaps),
            %% Return full torch data for TUI compatibility
            TorchId = initiate_torch_v1:get_torch_id(Cmd),
            hecate_api_utils:json_ok(201, #{
                torch_id => TorchId,
                name => initiate_torch_v1:get_name(Cmd),
                brief => initiate_torch_v1:get_brief(Cmd),
                status => 3,  %% INITIATED | DNA_ACTIVE flags
                initiated_at => erlang:system_time(millisecond),
                initiated_by => initiate_torch_v1:get_initiated_by(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_pg(EventMaps) ->
    lists:foreach(fun(E) ->
        torch_initiated_v1_to_pg:emit(E)
    end, EventMaps).

emit_to_mesh(EventMaps) ->
    lists:foreach(fun(E) -> torch_initiated_v1_to_mesh:emit(E) end, EventMaps).
