-module(maybe_rename_briefcase_item).
-export([handle_from_map/1]).
handle_from_map(Payload) ->
    case rename_briefcase_item_v1:from_map(Payload) of
        {ok, Cmd} ->
            case rename_briefcase_item_v1:validate(Cmd) of
                {ok, _} ->
                    M = rename_briefcase_item_v1:to_map(Cmd),
                    {ok, [briefcase_item_renamed_v1:new(M)]};
                Err -> Err
            end;
        Err -> Err
    end.
