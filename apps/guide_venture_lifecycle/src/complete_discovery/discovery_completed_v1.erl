%%% @doc discovery_completed_v1 event
%%% Emitted when the discovery phase is completed for a venture.
-module(discovery_completed_v1).

-export([new/1, from_map/1, to_map/1, get_venture_id/1, get_completed_at/1]).

-record(discovery_completed_v1, {
    venture_id   :: binary(),
    completed_at :: non_neg_integer()
}).

-export_type([discovery_completed_v1/0]).
-opaque discovery_completed_v1() :: #discovery_completed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> discovery_completed_v1().
new(#{venture_id := VentureId} = Params) ->
    #discovery_completed_v1{
        venture_id = VentureId,
        completed_at = maps:get(completed_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(discovery_completed_v1()) -> map().
to_map(#discovery_completed_v1{venture_id = V, completed_at = CA}) ->
    #{
        <<"event_type">> => <<"discovery_completed_v1">>,
        <<"venture_id">> => V,
        <<"completed_at">> => CA
    }.

-spec from_map(map()) -> {ok, discovery_completed_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #discovery_completed_v1{
                venture_id = VentureId,
                completed_at = get_value(completed_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(discovery_completed_v1()) -> binary().
get_venture_id(#discovery_completed_v1{venture_id = V}) -> V.

-spec get_completed_at(discovery_completed_v1()) -> non_neg_integer().
get_completed_at(#discovery_completed_v1{completed_at = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
