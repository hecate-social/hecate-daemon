%%% @doc API handler: POST /api/divisions/initiate
%%%
%%% Initiates a new division within a venture.
%%% Lives in the initiate_division desk for vertical slicing.
%%% @end
-module(initiate_division_api).

-include("division_alc_status.hrl").

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
    VentureId = hecate_api_utils:get_field(venture_id, Params),
    ContextName = hecate_api_utils:get_field(context_name, Params),
    InitiatedBy = hecate_api_utils:get_field(initiated_by, Params),

    case validate(VentureId, ContextName) of
        ok -> create_division(VentureId, ContextName, InitiatedBy, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _) -> {error, <<"venture_id is required">>};
validate(_, undefined) -> {error, <<"context_name is required">>};
validate(VentureId, _) when not is_binary(VentureId); byte_size(VentureId) =:= 0 ->
    {error, <<"venture_id must be a non-empty string">>};
validate(_, ContextName) when not is_binary(ContextName); byte_size(ContextName) =:= 0 ->
    {error, <<"context_name must be a non-empty string">>};
validate(_, _) -> ok.

create_division(VentureId, ContextName, InitiatedBy, Req) ->
    CmdParams = #{venture_id => VentureId, context_name => ContextName, initiated_by => InitiatedBy},
    case initiate_division_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_initiate_division:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            emit_to_pg(EventMaps),
            emit_to_mesh(EventMaps),
            DivisionId = initiate_division_v1:get_division_id(Cmd),
            Status = evoq_bit_flags:set(0, ?DA_INITIATED),
            StatusLabel = evoq_bit_flags:to_string(Status, ?DA_FLAG_MAP),
            hecate_api_utils:json_ok(201, #{
                division_id => DivisionId,
                venture_id => initiate_division_v1:get_venture_id(Cmd),
                context_name => initiate_division_v1:get_context_name(Cmd),
                status => Status,
                status_label => StatusLabel,
                initiated_at => erlang:system_time(millisecond),
                initiated_by => initiate_division_v1:get_initiated_by(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_pg(EventMaps) ->
    lists:foreach(fun(E) ->
        division_initiated_v1_to_pg:emit(E)
    end, EventMaps).

emit_to_mesh(EventMaps) ->
    lists:foreach(fun(E) -> division_initiated_v1_to_mesh:emit(E) end, EventMaps).
