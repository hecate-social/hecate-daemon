%%% @doc API handler: POST /api/divisions/:division_id/phase/pause
-module(pause_phase_api).

-export([init/2, routes/0]).

routes() -> [{"/api/divisions/:division_id/phase/pause", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case DivisionId of
        undefined ->
            hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} ->
                    do_pause_phase(DivisionId, Params, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_pause_phase(DivisionId, Params, Req) ->
    Phase = hecate_api_utils:get_field(phase, Params),
    Reason = hecate_api_utils:get_field(reason, Params),

    case validate(Phase) of
        ok -> create_command(DivisionId, Phase, Reason, Req);
        {error, ErrReason} -> hecate_api_utils:bad_request(ErrReason, Req)
    end.

validate(undefined) -> {error, <<"phase is required">>};
validate(P) when P =:= <<"dna">>; P =:= <<"anp">>; P =:= <<"tni">>; P =:= <<"dno">> -> ok;
validate(_) -> {error, <<"phase must be one of: dna, anp, tni, dno">>}.

create_command(DivisionId, Phase, Reason, Req) ->
    CmdParams = #{division_id => DivisionId, phase => Phase, reason => Reason},
    case pause_phase_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, ErrReason} -> hecate_api_utils:bad_request(ErrReason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_pause_phase:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                division_id => pause_phase_v1:get_division_id(Cmd),
                phase => pause_phase_v1:get_phase(Cmd),
                phase_paused => true,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
