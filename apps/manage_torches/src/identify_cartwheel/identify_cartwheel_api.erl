%%% @doc API handler: POST /api/torches/:torch_id/cartwheels/identify
%%%
%%% Identifies a cartwheel (bounded context) within a torch.
%%% This is the parent declaring "I need a cartwheel called X".
%%% Lives in the identify_cartwheel spoke for vertical slicing.
%%% @end
-module(identify_cartwheel_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    TorchId = cowboy_req:binding(torch_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_identify(TorchId, Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_identify(TorchId, Params, Req) ->
    ContextName = hecate_api_utils:get_field(context_name, Params),
    Description = hecate_api_utils:get_field(description, Params),
    IdentifiedBy = hecate_api_utils:get_field(identified_by, Params),

    case validate(ContextName) of
        ok -> create_identification(TorchId, ContextName, Description, IdentifiedBy, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined) -> {error, <<"context_name is required">>};
validate(Name) when not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, <<"context_name must be a non-empty string">>};
validate(_) -> ok.

create_identification(TorchId, ContextName, Description, IdentifiedBy, Req) ->
    CmdParams = #{
        torch_id => TorchId,
        context_name => ContextName,
        description => Description,
        identified_by => IdentifiedBy
    },
    case identify_cartwheel_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, TorchId, ContextName, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, TorchId, ContextName, Req) ->
    case maybe_identify_cartwheel:handle(Cmd) of
        {ok, Events} ->
            EventMaps = [cartwheel_identified_v1:to_map(E) || E <- Events],
            emit_to_mesh(EventMaps),
            CartwheelId = extract_cartwheel_id(EventMaps),
            hecate_api_utils:json_ok(201, #{
                torch_id => TorchId,
                cartwheel_id => CartwheelId,
                context_name => ContextName,
                version => 0,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_mesh(EventMaps) ->
    lists:foreach(fun(E) -> cartwheel_identified_v1_to_mesh:emit(E) end, EventMaps).

extract_cartwheel_id([#{<<"cartwheel_id">> := Id} | _]) -> Id;
extract_cartwheel_id(_) -> undefined.
