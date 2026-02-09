%%% @doc maybe_submit_vision handler
%%% Business logic for submitting (finalizing) torch vision.
-module(maybe_submit_vision).

-export([handle/1]).

%% @doc Handle submit_vision_v1 command (business logic only)
%% Returns list of events to emit.
-spec handle(submit_vision_v1:submit_vision_v1()) ->
    {ok, [torch_vision_submitted_v1:torch_vision_submitted_v1()]} | {error, term()}.
handle(Cmd) ->
    TorchId = submit_vision_v1:get_torch_id(Cmd),
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
    torch_vision_submitted_v1:new(#{
        torch_id => submit_vision_v1:get_torch_id(Cmd),
        submitted_by => submit_vision_v1:get_submitted_by(Cmd)
    }).
