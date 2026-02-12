%%% @doc pause_discovery_v1 command
%%% Pauses the discovery phase for a venture.
-module(pause_discovery_v1).

-export([new/1, from_map/1, validate/1, to_map/1, get_venture_id/1, get_reason/1]).

-record(pause_discovery_v1, {
    venture_id :: binary(),
    reason     :: binary() | undefined
}).

-export_type([pause_discovery_v1/0]).
-opaque pause_discovery_v1() :: #pause_discovery_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, pause_discovery_v1()} | {error, term()}.
new(#{venture_id := VentureId} = Params) ->
    Cmd = #pause_discovery_v1{
        venture_id = VentureId,
        reason = maps:get(reason, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(pause_discovery_v1()) -> ok | {error, term()}.
validate(#pause_discovery_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(_) -> ok.

-spec to_map(pause_discovery_v1()) -> map().
to_map(#pause_discovery_v1{venture_id = V, reason = R}) ->
    #{
        <<"command_type">> => <<"pause_discovery">>,
        <<"venture_id">> => V,
        <<"reason">> => R
    }.

-spec from_map(map()) -> {ok, pause_discovery_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    Reason = get_value(reason, Map),
    case VentureId of
        undefined -> {error, missing_required_fields};
        _ -> new(#{venture_id => VentureId, reason => Reason})
    end.

-spec get_venture_id(pause_discovery_v1()) -> binary().
get_venture_id(#pause_discovery_v1{venture_id = V}) -> V.

-spec get_reason(pause_discovery_v1()) -> binary() | undefined.
get_reason(#pause_discovery_v1{reason = V}) -> V.

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
