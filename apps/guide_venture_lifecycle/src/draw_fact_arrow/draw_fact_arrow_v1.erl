%%% @doc draw_fact_arrow_v1 command
%%% Draws a fact arrow between two clusters during Big Picture Event Storming.
-module(draw_fact_arrow_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_from_cluster/1, get_to_cluster/1, get_fact_name/1]).

-record(draw_fact_arrow_v1, {
    venture_id   :: binary(),
    from_cluster :: binary(),
    to_cluster   :: binary(),
    fact_name    :: binary()
}).

-export_type([draw_fact_arrow_v1/0]).
-opaque draw_fact_arrow_v1() :: #draw_fact_arrow_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, draw_fact_arrow_v1()} | {error, term()}.
new(#{venture_id := VentureId, from_cluster := FromCluster,
      to_cluster := ToCluster, fact_name := FactName} = _Params) ->
    Cmd = #draw_fact_arrow_v1{
        venture_id = VentureId,
        from_cluster = FromCluster,
        to_cluster = ToCluster,
        fact_name = FactName
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(draw_fact_arrow_v1()) -> ok | {error, term()}.
validate(#draw_fact_arrow_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#draw_fact_arrow_v1{from_cluster = F}) when not is_binary(F); F =:= <<>> ->
    {error, {invalid_field, from_cluster}};
validate(#draw_fact_arrow_v1{to_cluster = T}) when not is_binary(T); T =:= <<>> ->
    {error, {invalid_field, to_cluster}};
validate(#draw_fact_arrow_v1{fact_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, fact_name}};
validate(_) -> ok.

-spec to_map(draw_fact_arrow_v1()) -> map().
to_map(#draw_fact_arrow_v1{venture_id = V, from_cluster = FC,
                            to_cluster = TC, fact_name = FN}) ->
    #{
        <<"command_type">> => <<"draw_fact_arrow">>,
        <<"venture_id">> => V,
        <<"from_cluster">> => FC,
        <<"to_cluster">> => TC,
        <<"fact_name">> => FN
    }.

-spec from_map(map()) -> {ok, draw_fact_arrow_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    FromCluster = get_value(from_cluster, Map),
    ToCluster = get_value(to_cluster, Map),
    FactName = get_value(fact_name, Map),
    case {VentureId, FromCluster, ToCluster, FactName} of
        {undefined, _, _, _} -> {error, missing_required_fields};
        {_, undefined, _, _} -> {error, missing_required_fields};
        {_, _, undefined, _} -> {error, missing_required_fields};
        {_, _, _, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, from_cluster => FromCluster,
                  to_cluster => ToCluster, fact_name => FactName})
    end.

-spec get_venture_id(draw_fact_arrow_v1()) -> binary().
get_venture_id(#draw_fact_arrow_v1{venture_id = V}) -> V.

-spec get_from_cluster(draw_fact_arrow_v1()) -> binary().
get_from_cluster(#draw_fact_arrow_v1{from_cluster = V}) -> V.

-spec get_to_cluster(draw_fact_arrow_v1()) -> binary().
get_to_cluster(#draw_fact_arrow_v1{to_cluster = V}) -> V.

-spec get_fact_name(draw_fact_arrow_v1()) -> binary().
get_fact_name(#draw_fact_arrow_v1{fact_name = V}) -> V.

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
