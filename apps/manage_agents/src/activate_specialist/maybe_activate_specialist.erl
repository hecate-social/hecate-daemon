%%% @doc maybe_activate_specialist handler
%%% Business logic for activating specialist agents.
%%% Validates the command and creates the event.
-module(maybe_activate_specialist).

-export([handle/1, handle/2]).

%% @doc Handle activate_specialist_v1 command (business logic only)
-spec handle(activate_specialist_v1:activate_specialist_v1()) ->
    {ok, [specialist_activated_v1:specialist_activated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(activate_specialist_v1:activate_specialist_v1(), term()) ->
    {ok, [specialist_activated_v1:specialist_activated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    TorchId = activate_specialist_v1:get_torch_id(Cmd),
    Role = activate_specialist_v1:get_role(Cmd),
    case validate_command(TorchId, Role) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

validate_command(TorchId, Role) when
    is_binary(TorchId), byte_size(TorchId) > 0,
    (Role =:= dna orelse Role =:= anp orelse Role =:= tni orelse Role =:= dno) ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    specialist_activated_v1:new(#{
        agent_id => activate_specialist_v1:get_agent_id(Cmd),
        torch_id => activate_specialist_v1:get_torch_id(Cmd),
        role => activate_specialist_v1:get_role(Cmd)
    }).
