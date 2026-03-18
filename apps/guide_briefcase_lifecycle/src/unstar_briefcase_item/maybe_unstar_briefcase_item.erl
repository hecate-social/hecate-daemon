-module(maybe_unstar_briefcase_item).
-export([handle_from_map/1]).
handle_from_map(Payload) ->
    case unstar_briefcase_item_v1:from_map(Payload) of
        {ok, Cmd} ->
            case unstar_briefcase_item_v1:validate(Cmd) of
                {ok, _} ->
                    M = unstar_briefcase_item_v1:to_map(Cmd),
                    {ok, [briefcase_item_unstarred_v1:new(M)]};
                Err -> Err
            end;
        Err -> Err
    end.
