%%% @doc event_cluster_named_v1 event
%%% Emitted when an event cluster is named during Big Picture Event Storming.
-module(event_cluster_named_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_cluster_id/1, get_name/1, get_named_at/1]).

-record(event_cluster_named_v1, {
    venture_id :: binary(),
    cluster_id :: binary(),
    name       :: binary(),
    named_at   :: non_neg_integer()
}).

-export_type([event_cluster_named_v1/0]).
-opaque event_cluster_named_v1() :: #event_cluster_named_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> event_cluster_named_v1().
new(#{venture_id := VentureId, cluster_id := ClusterId, name := Name} = Params) ->
    #event_cluster_named_v1{
        venture_id = VentureId,
        cluster_id = ClusterId,
        name = Name,
        named_at = maps:get(named_at, Params, erlang:system_time(millisecond))
    }.

-spec to_map(event_cluster_named_v1()) -> map().
to_map(#event_cluster_named_v1{venture_id = V, cluster_id = CI, name = N, named_at = NA}) ->
    #{
        <<"event_type">> => <<"event_cluster_named_v1">>,
        <<"venture_id">> => V,
        <<"cluster_id">> => CI,
        <<"name">> => N,
        <<"named_at">> => NA
    }.

-spec from_map(map()) -> {ok, event_cluster_named_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #event_cluster_named_v1{
                venture_id = VentureId,
                cluster_id = get_value(cluster_id, Map),
                name = get_value(name, Map),
                named_at = get_value(named_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_venture_id(event_cluster_named_v1()) -> binary().
get_venture_id(#event_cluster_named_v1{venture_id = V}) -> V.

-spec get_cluster_id(event_cluster_named_v1()) -> binary().
get_cluster_id(#event_cluster_named_v1{cluster_id = V}) -> V.

-spec get_name(event_cluster_named_v1()) -> binary().
get_name(#event_cluster_named_v1{name = V}) -> V.

-spec get_named_at(event_cluster_named_v1()) -> non_neg_integer().
get_named_at(#event_cluster_named_v1{named_at = V}) -> V.

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
