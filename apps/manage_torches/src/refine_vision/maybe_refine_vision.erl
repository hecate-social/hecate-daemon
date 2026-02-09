%%% @doc maybe_refine_vision handler
%%% Business logic for refining torch vision during DnA.
-module(maybe_refine_vision).

-export([handle/1]).

%% @doc Handle refine_vision_v1 command (business logic only)
%% Returns list of events to emit.
-spec handle(refine_vision_v1:refine_vision_v1()) ->
    {ok, [torch_vision_refined_v1:torch_vision_refined_v1()]} | {error, term()}.
handle(Cmd) ->
    TorchId = refine_vision_v1:get_torch_id(Cmd),
    case validate_command(TorchId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

validate_command(TorchId) when is_binary(TorchId), byte_size(TorchId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_torch_id}.

create_event(Cmd) ->
    torch_vision_refined_v1:new(#{
        torch_id => refine_vision_v1:get_torch_id(Cmd),
        brief => refine_vision_v1:get_brief(Cmd),
        repos => refine_vision_v1:get_repos(Cmd),
        skills => refine_vision_v1:get_skills(Cmd),
        context_map => refine_vision_v1:get_context_map(Cmd),
        refined_by => refine_vision_v1:get_refined_by(Cmd)
    }).
