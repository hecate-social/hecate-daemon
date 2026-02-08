%%% @doc Query: list build verifications for a project
-module(list_build_verifications).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{cartwheel_id := CartwheelId} = Filters) ->
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Sql = "SELECT build_id, cartwheel_id, result, notes, verified_at "
          "FROM build_verifications WHERE cartwheel_id = ?1"
          " ORDER BY verified_at DESC"
          " LIMIT ?2"
          " OFFSET ?3",

    case query_cartwheels_store:query(Sql, [CartwheelId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map({BuildId, CartwheelId, Result, Notes, VerifiedAt}) ->
    #{
        build_id => BuildId,
        cartwheel_id => CartwheelId,
        result => Result,
        notes => Notes,
        verified_at => VerifiedAt
    }.
