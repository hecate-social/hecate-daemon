%%% @doc maybe_initiate_torch handler
%%% Business logic for initiating torches.
%%% Validates the command and creates the event.
-module(maybe_initiate_torch).

-export([handle/1, handle/2]).

%% @doc Handle initiate_torch_v1 command (business logic only)
-spec handle(initiate_torch_v1:initiate_torch_v1()) ->
    {ok, [torch_initiated_v1:torch_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(initiate_torch_v1:initiate_torch_v1(), term()) ->
    {ok, [torch_initiated_v1:torch_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    Name = initiate_torch_v1:get_name(Cmd),
    case validate_command(Name) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

validate_command(Name) when is_binary(Name), byte_size(Name) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    torch_initiated_v1:new(#{
        torch_id => initiate_torch_v1:get_torch_id(Cmd),
        name => initiate_torch_v1:get_name(Cmd),
        brief => initiate_torch_v1:get_brief(Cmd),
        initiated_by => initiate_torch_v1:get_initiated_by(Cmd)
    }).
