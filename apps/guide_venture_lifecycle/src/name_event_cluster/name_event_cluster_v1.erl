%%% @doc name_event_cluster_v1 command
%%% Names an event cluster during Big Picture Event Storming.
-module(name_event_cluster_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_cluster_id/1, get_name/1]).

-record(name_event_cluster_v1, {
    venture_id :: binary(),
    cluster_id :: binary(),
    name       :: binary()
}).

-export_type([name_event_cluster_v1/0]).
-opaque name_event_cluster_v1() :: #name_event_cluster_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, name_event_cluster_v1()} | {error, term()}.
new(#{venture_id := VentureId, cluster_id := ClusterId, name := Name} = _Params) ->
    Cmd = #name_event_cluster_v1{
        venture_id = VentureId,
        cluster_id = ClusterId,
        name = Name
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(name_event_cluster_v1()) -> ok | {error, term()}.
validate(#name_event_cluster_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#name_event_cluster_v1{cluster_id = C}) when not is_binary(C); C =:= <<>> ->
    {error, {invalid_field, cluster_id}};
validate(#name_event_cluster_v1{name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, name}};
validate(_) -> ok.

-spec to_map(name_event_cluster_v1()) -> map().
to_map(#name_event_cluster_v1{venture_id = V, cluster_id = C, name = N}) ->
    #{
        <<"command_type">> => <<"name_event_cluster">>,
        <<"venture_id">> => V,
        <<"cluster_id">> => C,
        <<"name">> => N
    }.

-spec from_map(map()) -> {ok, name_event_cluster_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    ClusterId = get_value(cluster_id, Map),
    Name = get_value(name, Map),
    case {VentureId, ClusterId, Name} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, cluster_id => ClusterId, name => Name})
    end.

-spec get_venture_id(name_event_cluster_v1()) -> binary().
get_venture_id(#name_event_cluster_v1{venture_id = V}) -> V.

-spec get_cluster_id(name_event_cluster_v1()) -> binary().
get_cluster_id(#name_event_cluster_v1{cluster_id = V}) -> V.

-spec get_name(name_event_cluster_v1()) -> binary().
get_name(#name_event_cluster_v1{name = V}) -> V.

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
