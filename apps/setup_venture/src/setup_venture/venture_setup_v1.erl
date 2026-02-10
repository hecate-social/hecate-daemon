%%% @doc venture_setup_v1 event
%%% Emitted when a venture is successfully set up.
-module(venture_setup_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_venture_id/1, get_name/1, get_brief/1, get_initiated_by/1, get_initiated_at/1]).

-record(venture_setup_v1, {
    venture_id   :: binary(),
    name         :: binary(),
    brief        :: binary() | undefined,
    initiated_by :: binary() | undefined,
    initiated_at :: integer()
}).

-export_type([venture_setup_v1/0]).
-opaque venture_setup_v1() :: #venture_setup_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> venture_setup_v1().
new(#{venture_id := VentureId, name := Name} = Params) ->
    #venture_setup_v1{
        venture_id = VentureId,
        name = Name,
        brief = maps:get(brief, Params, undefined),
        initiated_by = maps:get(initiated_by, Params, undefined),
        initiated_at = erlang:system_time(millisecond)
    }.

-spec to_map(venture_setup_v1()) -> map().
to_map(#venture_setup_v1{} = E) ->
    #{
        <<"event_type">> => <<"venture_setup_v1">>,
        <<"venture_id">> => E#venture_setup_v1.venture_id,
        <<"name">> => E#venture_setup_v1.name,
        <<"brief">> => E#venture_setup_v1.brief,
        <<"initiated_by">> => E#venture_setup_v1.initiated_by,
        <<"initiated_at">> => E#venture_setup_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, venture_setup_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    Name = get_value(name, Map),
    case {VentureId, Name} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #venture_setup_v1{
                venture_id = VentureId,
                name = Name,
                brief = get_value(brief, Map, undefined),
                initiated_by = get_value(initiated_by, Map, undefined),
                initiated_at = get_value(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_venture_id(venture_setup_v1()) -> binary().
get_venture_id(#venture_setup_v1{venture_id = V}) -> V.

-spec get_name(venture_setup_v1()) -> binary().
get_name(#venture_setup_v1{name = V}) -> V.

-spec get_brief(venture_setup_v1()) -> binary() | undefined.
get_brief(#venture_setup_v1{brief = V}) -> V.

-spec get_initiated_by(venture_setup_v1()) -> binary() | undefined.
get_initiated_by(#venture_setup_v1{initiated_by = V}) -> V.

-spec get_initiated_at(venture_setup_v1()) -> integer().
get_initiated_at(#venture_setup_v1{initiated_at = V}) -> V.

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
