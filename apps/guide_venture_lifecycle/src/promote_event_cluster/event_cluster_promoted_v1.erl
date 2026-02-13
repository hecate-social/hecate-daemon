%%% @doc event_cluster_promoted_v1 event
%%% Emitted when an event cluster is promoted to a division during Big Picture Event Storming.
%%% This bridges the storm into the venture lifecycle.
-module(event_cluster_promoted_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_cluster_id/1, get_division_id/1, get_promoted_at/1]).

-record(event_cluster_promoted_v1, {
    venture_id  :: binary(),
    cluster_id  :: binary(),
    division_id :: binary(),
    promoted_at :: non_neg_integer()
}).

-export_type([event_cluster_promoted_v1/0]).
-opaque event_cluster_promoted_v1() :: #event_cluster_promoted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> event_cluster_promoted_v1().
new(#{venture_id := VentureId, cluster_id := ClusterId} = Params) ->
    #event_cluster_promoted_v1{
        venture_id = VentureId,
        cluster_id = ClusterId,
        division_id = maps:get(division_id, Params, generate_id(<<"division-">>)),
        promoted_at = maps:get(promoted_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(event_cluster_promoted_v1()) -> map().
to_map(#event_cluster_promoted_v1{venture_id = V, cluster_id = CI,
                                   division_id = DI, promoted_at = PA}) ->
    #{
        <<"event_type">> => <<"event_cluster_promoted_v1">>,
        <<"venture_id">> => V,
        <<"cluster_id">> => CI,
        <<"division_id">> => DI,
        <<"promoted_at">> => PA
    }.

-spec from_map(map()) -> {ok, event_cluster_promoted_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #event_cluster_promoted_v1{
                venture_id = VentureId,
                cluster_id = get_value(cluster_id, Map),
                division_id = get_value(division_id, Map),
                promoted_at = get_value(promoted_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(event_cluster_promoted_v1()) -> binary().
get_venture_id(#event_cluster_promoted_v1{venture_id = V}) -> V.

-spec get_cluster_id(event_cluster_promoted_v1()) -> binary().
get_cluster_id(#event_cluster_promoted_v1{cluster_id = V}) -> V.

-spec get_division_id(event_cluster_promoted_v1()) -> binary().
get_division_id(#event_cluster_promoted_v1{division_id = V}) -> V.

-spec get_promoted_at(event_cluster_promoted_v1()) -> non_neg_integer().
get_promoted_at(#event_cluster_promoted_v1{promoted_at = V}) -> V.

generate_id(Prefix) ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<Prefix/binary, Ts/binary, "-", Rand/binary>>.

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
