%%% @doc maybe_activate_cartwheel handler
%%% Business logic for activating cartwheels within a torch.
%%% Validates the command and creates the event.
-module(maybe_activate_cartwheel).

-export([handle/1, handle/2]).

%% @doc Handle activate_cartwheel_v1 command (business logic only)
-spec handle(activate_cartwheel_v1:activate_cartwheel_v1()) ->
    {ok, [cartwheel_activated_v1:cartwheel_activated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(activate_cartwheel_v1:activate_cartwheel_v1(), term()) ->
    {ok, [cartwheel_activated_v1:cartwheel_activated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    TorchId = activate_cartwheel_v1:get_torch_id(Cmd),
    CartwheelId = activate_cartwheel_v1:get_cartwheel_id(Cmd),
    ContextName = activate_cartwheel_v1:get_context_name(Cmd),
    case validate_command(TorchId, CartwheelId, ContextName) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

validate_command(TorchId, CartwheelId, ContextName)
  when is_binary(TorchId), byte_size(TorchId) > 0,
       is_binary(CartwheelId), byte_size(CartwheelId) > 0,
       is_binary(ContextName), byte_size(ContextName) > 0 ->
    ok;
validate_command(TorchId, _, _) when not is_binary(TorchId); byte_size(TorchId) =:= 0 ->
    {error, invalid_torch_id};
validate_command(_, CartwheelId, _) when not is_binary(CartwheelId); byte_size(CartwheelId) =:= 0 ->
    {error, invalid_cartwheel_id};
validate_command(_, _, ContextName) when not is_binary(ContextName); byte_size(ContextName) =:= 0 ->
    {error, invalid_context_name}.

create_event(Cmd) ->
    cartwheel_activated_v1:new(#{
        torch_id => activate_cartwheel_v1:get_torch_id(Cmd),
        cartwheel_id => activate_cartwheel_v1:get_cartwheel_id(Cmd),
        context_name => activate_cartwheel_v1:get_context_name(Cmd)
    }).
