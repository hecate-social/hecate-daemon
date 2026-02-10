-module(get_venture_status).
-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found}.
execute(VentureId) ->
    venture_state:get_venture_status(VentureId).
