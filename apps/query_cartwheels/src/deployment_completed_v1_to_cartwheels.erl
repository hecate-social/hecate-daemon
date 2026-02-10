%%% @doc Projection: deployment_completed_v1 -> cartwheels table (UPDATE status bit flag + completed_at)
-module(deployment_completed_v1_to_cartwheels).

-include_lib("manage_cartwheels/include/cartwheel_status.hrl").

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    Id = get(cartwheel_id, Event),
    CompletedAt = get(completed_at, Event, erlang:system_time(millisecond)),
    %% 1. Set the DEPLOYMENT_COMPLETE flag and completed_at
    ok = query_cartwheels_store:execute(
        "UPDATE cartwheels SET status = status | ?1, completed_at = ?2 "
        "WHERE cartwheel_id = ?3",
        [?CW_DEPLOYMENT_COMPLETE, CompletedAt, Id]),
    %% 2. Read back new status, recompute label
    case query_cartwheels_store:query(
        "SELECT status FROM cartwheels WHERE cartwheel_id = ?1", [Id]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?CW_FLAG_MAP),
            query_cartwheels_store:execute(
                "UPDATE cartwheels SET status_label = ?1 WHERE cartwheel_id = ?2",
                [Label, Id]);
        _ -> ok
    end.

%% @doc Get value from event map, handling both atom and binary keys.
-spec get(atom(), map()) -> term().
get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.

-spec get(atom(), map(), term()) -> term().
get(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
