%%% @doc cluster_event_sticky_v1 command
%%% Clusters an event sticky into a cluster during Big Picture Event Storming.
%%% If target_cluster_id matches an existing cluster, the sticky joins it.
%%% If target_cluster_id matches another sticky, a new cluster emerges.
-module(cluster_event_sticky_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_sticky_id/1, get_target_cluster_id/1]).

-record(cluster_event_sticky_v1, {
    venture_id        :: binary(),
    sticky_id         :: binary(),
    target_cluster_id :: binary()
}).

-export_type([cluster_event_sticky_v1/0]).
-opaque cluster_event_sticky_v1() :: #cluster_event_sticky_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, cluster_event_sticky_v1()} | {error, term()}.
new(#{venture_id := VentureId, sticky_id := StickyId, target_cluster_id := TargetClusterId} = _Params) ->
    Cmd = #cluster_event_sticky_v1{
        venture_id = VentureId,
        sticky_id = StickyId,
        target_cluster_id = TargetClusterId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(cluster_event_sticky_v1()) -> ok | {error, term()}.
validate(#cluster_event_sticky_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#cluster_event_sticky_v1{sticky_id = S}) when not is_binary(S); S =:= <<>> ->
    {error, {invalid_field, sticky_id}};
validate(#cluster_event_sticky_v1{target_cluster_id = T}) when not is_binary(T); T =:= <<>> ->
    {error, {invalid_field, target_cluster_id}};
validate(_) -> ok.

-spec to_map(cluster_event_sticky_v1()) -> map().
to_map(#cluster_event_sticky_v1{venture_id = V, sticky_id = S, target_cluster_id = T}) ->
    #{
        <<"command_type">> => <<"cluster_event_sticky">>,
        <<"venture_id">> => V,
        <<"sticky_id">> => S,
        <<"target_cluster_id">> => T
    }.

-spec from_map(map()) -> {ok, cluster_event_sticky_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    StickyId = get_value(sticky_id, Map),
    TargetClusterId = get_value(target_cluster_id, Map),
    case {VentureId, StickyId, TargetClusterId} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, sticky_id => StickyId,
                  target_cluster_id => TargetClusterId})
    end.

-spec get_venture_id(cluster_event_sticky_v1()) -> binary().
get_venture_id(#cluster_event_sticky_v1{venture_id = V}) -> V.

-spec get_sticky_id(cluster_event_sticky_v1()) -> binary().
get_sticky_id(#cluster_event_sticky_v1{sticky_id = V}) -> V.

-spec get_target_cluster_id(cluster_event_sticky_v1()) -> binary().
get_target_cluster_id(#cluster_event_sticky_v1{target_cluster_id = V}) -> V.

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
