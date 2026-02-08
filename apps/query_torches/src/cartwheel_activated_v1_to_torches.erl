%%% @doc Projection: cartwheel_activated_v1 -> torches table
-module(cartwheel_activated_v1_to_torches).

-export([project/1]).

%% @doc Project cartwheel_activated_v1 event to torches table.
%% Updates the active_cartwheel_id for the torch.
-spec project(map()) -> ok | {error, term()}.
project(#{torch_id := TorchId, cartwheel_id := CartwheelId} = _E) ->
    Sql = "UPDATE torches SET active_cartwheel_id = ?1 WHERE torch_id = ?2",
    query_torches_store:execute(Sql, [CartwheelId, TorchId]).
