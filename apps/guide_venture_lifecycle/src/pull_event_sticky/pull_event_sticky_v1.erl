%%% @doc pull_event_sticky_v1 command
%%% Pulls (removes) an event sticky during Big Picture Event Storming.
-module(pull_event_sticky_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_sticky_id/1]).

-record(pull_event_sticky_v1, {
    venture_id :: binary(),
    sticky_id  :: binary()
}).

-export_type([pull_event_sticky_v1/0]).
-opaque pull_event_sticky_v1() :: #pull_event_sticky_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, pull_event_sticky_v1()} | {error, term()}.
new(#{venture_id := VentureId, sticky_id := StickyId}) ->
    Cmd = #pull_event_sticky_v1{
        venture_id = VentureId,
        sticky_id = StickyId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(pull_event_sticky_v1()) -> ok | {error, term()}.
validate(#pull_event_sticky_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#pull_event_sticky_v1{sticky_id = S}) when not is_binary(S); S =:= <<>> ->
    {error, {invalid_field, sticky_id}};
validate(_) -> ok.

-spec to_map(pull_event_sticky_v1()) -> map().
to_map(#pull_event_sticky_v1{venture_id = V, sticky_id = S}) ->
    #{
        <<"command_type">> => <<"pull_event_sticky">>,
        <<"venture_id">> => V,
        <<"sticky_id">> => S
    }.

-spec from_map(map()) -> {ok, pull_event_sticky_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    StickyId = get_value(sticky_id, Map),
    case {VentureId, StickyId} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ -> new(#{venture_id => VentureId, sticky_id => StickyId})
    end.

-spec get_venture_id(pull_event_sticky_v1()) -> binary().
get_venture_id(#pull_event_sticky_v1{venture_id = V}) -> V.

-spec get_sticky_id(pull_event_sticky_v1()) -> binary().
get_sticky_id(#pull_event_sticky_v1{sticky_id = V}) -> V.

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
