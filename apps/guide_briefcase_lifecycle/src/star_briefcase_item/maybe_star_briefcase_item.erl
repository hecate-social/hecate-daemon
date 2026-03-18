-module(maybe_star_briefcase_item).
-export([handle_from_map/1]).
handle_from_map(Payload) ->
    case star_briefcase_item_v1:from_map(Payload) of
        {ok, Cmd} ->
            case star_briefcase_item_v1:validate(Cmd) of
                {ok, _} ->
                    M = star_briefcase_item_v1:to_map(Cmd),
                    {ok, [briefcase_item_starred_v1:new(M)]};
                Err -> Err
            end;
        Err -> Err
    end.
