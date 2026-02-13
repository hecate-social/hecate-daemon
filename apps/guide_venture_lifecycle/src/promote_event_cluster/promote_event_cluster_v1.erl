%%% @doc promote_event_cluster_v1 command
%%% Promotes an event cluster to a division during Big Picture Event Storming.
%%% Bridges the storm phase into the venture lifecycle by identifying a division.
-module(promote_event_cluster_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_cluster_id/1]).

-record(promote_event_cluster_v1, {
    venture_id :: binary(),
    cluster_id :: binary()
}).

-export_type([promote_event_cluster_v1/0]).
-opaque promote_event_cluster_v1() :: #promote_event_cluster_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, promote_event_cluster_v1()} | {error, term()}.
new(#{venture_id := VentureId, cluster_id := ClusterId} = _Params) ->
    Cmd = #promote_event_cluster_v1{
        venture_id = VentureId,
        cluster_id = ClusterId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(promote_event_cluster_v1()) -> ok | {error, term()}.
validate(#promote_event_cluster_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#promote_event_cluster_v1{cluster_id = C}) when not is_binary(C); C =:= <<>> ->
    {error, {invalid_field, cluster_id}};
validate(_) -> ok.

-spec to_map(promote_event_cluster_v1()) -> map().
to_map(#promote_event_cluster_v1{venture_id = V, cluster_id = C}) ->
    #{
        <<"command_type">> => <<"promote_event_cluster">>,
        <<"venture_id">> => V,
        <<"cluster_id">> => C
    }.

-spec from_map(map()) -> {ok, promote_event_cluster_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    ClusterId = get_value(cluster_id, Map),
    case {VentureId, ClusterId} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, cluster_id => ClusterId})
    end.

-spec get_venture_id(promote_event_cluster_v1()) -> binary().
get_venture_id(#promote_event_cluster_v1{venture_id = V}) -> V.

-spec get_cluster_id(promote_event_cluster_v1()) -> binary().
get_cluster_id(#promote_event_cluster_v1{cluster_id = V}) -> V.

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
