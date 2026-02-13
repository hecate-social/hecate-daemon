%%% @doc dissolve_event_cluster_v1 command
%%% Dissolves an event cluster during Big Picture Event Storming.
%%% All stickies in the cluster become unclustered.
-module(dissolve_event_cluster_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_cluster_id/1]).

-record(dissolve_event_cluster_v1, {
    venture_id :: binary(),
    cluster_id :: binary()
}).

-export_type([dissolve_event_cluster_v1/0]).
-opaque dissolve_event_cluster_v1() :: #dissolve_event_cluster_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, dissolve_event_cluster_v1()} | {error, term()}.
new(#{venture_id := VentureId, cluster_id := ClusterId} = _Params) ->
    Cmd = #dissolve_event_cluster_v1{
        venture_id = VentureId,
        cluster_id = ClusterId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(dissolve_event_cluster_v1()) -> ok | {error, term()}.
validate(#dissolve_event_cluster_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#dissolve_event_cluster_v1{cluster_id = C}) when not is_binary(C); C =:= <<>> ->
    {error, {invalid_field, cluster_id}};
validate(_) -> ok.

-spec to_map(dissolve_event_cluster_v1()) -> map().
to_map(#dissolve_event_cluster_v1{venture_id = V, cluster_id = C}) ->
    #{
        <<"command_type">> => <<"dissolve_event_cluster">>,
        <<"venture_id">> => V,
        <<"cluster_id">> => C
    }.

-spec from_map(map()) -> {ok, dissolve_event_cluster_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    ClusterId = get_value(cluster_id, Map),
    case {VentureId, ClusterId} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, cluster_id => ClusterId})
    end.

-spec get_venture_id(dissolve_event_cluster_v1()) -> binary().
get_venture_id(#dissolve_event_cluster_v1{venture_id = V}) -> V.

-spec get_cluster_id(dissolve_event_cluster_v1()) -> binary().
get_cluster_id(#dissolve_event_cluster_v1{cluster_id = V}) -> V.

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
