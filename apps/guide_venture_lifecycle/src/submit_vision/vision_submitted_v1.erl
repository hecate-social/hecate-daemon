%%% @doc vision_submitted_v1 event
%%% Emitted when a venture's vision is finalized.
-module(vision_submitted_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_venture_id/1, get_submitted_at/1]).

-record(vision_submitted_v1, {
    venture_id   :: binary(),
    submitted_at :: integer()
}).

-export_type([vision_submitted_v1/0]).
-opaque vision_submitted_v1() :: #vision_submitted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> vision_submitted_v1().
new(#{venture_id := VentureId}) ->
    #vision_submitted_v1{
        venture_id = VentureId,
        submitted_at = erlang:system_time(millisecond)
    }.

-spec to_map(vision_submitted_v1()) -> map().
to_map(#vision_submitted_v1{} = E) ->
    #{
        <<"event_type">> => <<"vision_submitted_v1">>,
        <<"venture_id">> => E#vision_submitted_v1.venture_id,
        <<"submitted_at">> => E#vision_submitted_v1.submitted_at
    }.

-spec from_map(map()) -> {ok, vision_submitted_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #vision_submitted_v1{
                venture_id = VentureId,
                submitted_at = get_value(submitted_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_venture_id(vision_submitted_v1()) -> binary().
get_venture_id(#vision_submitted_v1{venture_id = V}) -> V.

-spec get_submitted_at(vision_submitted_v1()) -> integer().
get_submitted_at(#vision_submitted_v1{submitted_at = V}) -> V.

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
