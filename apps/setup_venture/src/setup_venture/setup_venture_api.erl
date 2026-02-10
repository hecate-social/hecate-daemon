%%% @doc API handler: POST /api/ventures/setup
%%%
%%% Sets up a new venture (business endeavor).
%%% Lives in the setup_venture desk for vertical slicing.
%%% @end
-module(setup_venture_api).

-include("venture_status.hrl").

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_setup(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_setup(Params, Req) ->
    Name = hecate_api_utils:get_field(name, Params),
    Brief = hecate_api_utils:get_field(brief, Params),
    InitiatedBy = hecate_api_utils:get_field(initiated_by, Params),

    case validate(Name) of
        ok -> create_venture(Name, Brief, InitiatedBy, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined) -> {error, <<"name is required">>};
validate(Name) when not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, <<"name must be a non-empty string">>};
validate(_) -> ok.

create_venture(Name, Brief, InitiatedBy, Req) ->
    CmdParams = #{name => Name, brief => Brief, initiated_by => InitiatedBy},
    case setup_venture_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_setup_venture:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            %% INTERNAL: Emit to pg for projections (intra-daemon)
            emit_to_pg(EventMaps),
            %% EXTERNAL: Emit to mesh for other agents (WAN)
            emit_to_mesh(EventMaps),
            %% Return full venture data for TUI compatibility
            VentureId = setup_venture_v1:get_venture_id(Cmd),
            Status = evoq_bit_flags:set(0, ?VENTURE_SETUP),
            StatusLabel = evoq_bit_flags:to_string(Status, ?VENTURE_FLAG_MAP),
            hecate_api_utils:json_ok(201, #{
                venture_id => VentureId,
                name => setup_venture_v1:get_name(Cmd),
                brief => setup_venture_v1:get_brief(Cmd),
                status => Status,
                status_label => StatusLabel,
                initiated_at => erlang:system_time(millisecond),
                initiated_by => setup_venture_v1:get_initiated_by(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_pg(EventMaps) ->
    lists:foreach(fun(E) ->
        venture_setup_v1_to_pg:emit(E)
    end, EventMaps).

emit_to_mesh(EventMaps) ->
    lists:foreach(fun(E) -> venture_setup_v1_to_mesh:emit(E) end, EventMaps).
