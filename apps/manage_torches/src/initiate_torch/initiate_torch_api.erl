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
    case maybe_initiate_torch:handle(Cmd) of
        {ok, Events} ->
            EventMaps = [torch_initiated_v1:to_map(E) || E <- Events],
            emit_to_mesh(EventMaps),
            hecate_api_utils:json_ok(201, #{
                torch_id => initiate_torch_v1:get_torch_id(Cmd),
                version => 0,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_mesh(EventMaps) ->
    lists:foreach(fun(E) -> torch_initiated_v1_to_mesh:emit(E) end, EventMaps).
