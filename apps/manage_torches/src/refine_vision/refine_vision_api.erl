%%% @doc API handler: POST /api/torches/:torch_id/vision/refine
%%%
%%% Iteratively refines a torch's vision during DnA phase.
%%% Lives in the refine_vision spoke for vertical slicing.
%%% @end
-module(refine_vision_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    TorchId = cowboy_req:binding(torch_id, Req0),
    case TorchId of
        undefined ->
            hecate_api_utils:bad_request(<<"torch_id is required">>, Req0);
        _ ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} ->
                    do_refine(TorchId, Params, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_refine(TorchId, Params, Req) ->
    Brief = hecate_api_utils:get_field(brief, Params),
    Repos = hecate_api_utils:get_field(repos, Params),
    Skills = hecate_api_utils:get_field(skills, Params),
    ContextMap = hecate_api_utils:get_field(context_map, Params),
    RefinedBy = hecate_api_utils:get_field(refined_by, Params),

    CmdParams = #{
        torch_id => TorchId,
        brief => Brief,
        repos => Repos,
        skills => Skills,
        context_map => ContextMap,
        refined_by => RefinedBy
    },
    case refine_vision_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_refine_vision:handle(Cmd) of
        {ok, Events} ->
            EventMaps = [torch_vision_refined_v1:to_map(E) || E <- Events],
            %% INTERNAL: Emit to pg for projections (intra-daemon)
            emit_to_pg(Events),
            hecate_api_utils:json_ok(200, #{
                torch_id => refine_vision_v1:get_torch_id(Cmd),
                refined => true,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_pg(Events) ->
    lists:foreach(fun(E) ->
        %% Convert record to atom-keyed map for pg consumers
        AtomMap = #{
            torch_id => torch_vision_refined_v1:get_torch_id(E),
            brief => torch_vision_refined_v1:get_brief(E),
            repos => torch_vision_refined_v1:get_repos(E),
            skills => torch_vision_refined_v1:get_skills(E),
            context_map => torch_vision_refined_v1:get_context_map(E),
            refined_by => torch_vision_refined_v1:get_refined_by(E),
            refined_at => torch_vision_refined_v1:get_refined_at(E)
        },
        torch_vision_refined_v1_to_pg:emit(AtomMap)
    end, Events).
