%%% @doc venture_archived_v1 event
%%% Emitted when a venture is archived (soft deleted).
-module(venture_archived_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_venture_id/1, get_archived_by/1, get_reason/1, get_archived_at/1]).

-record(venture_archived_v1, {
    venture_id  :: binary(),
    archived_by :: binary() | undefined,
    reason      :: binary() | undefined,
    archived_at :: integer()
}).

-export_type([venture_archived_v1/0]).
-opaque venture_archived_v1() :: #venture_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> venture_archived_v1().
new(#{venture_id := VentureId} = Params) ->
    #venture_archived_v1{
        venture_id = VentureId,
        archived_by = maps:get(archived_by, Params, undefined),
        reason = maps:get(reason, Params, undefined),
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(venture_archived_v1()) -> map().
to_map(#venture_archived_v1{} = E) ->
    #{
        <<"event_type">> => <<"venture_archived_v1">>,
        <<"venture_id">> => E#venture_archived_v1.venture_id,
        <<"archived_by">> => E#venture_archived_v1.archived_by,
        <<"reason">> => E#venture_archived_v1.reason,
        <<"archived_at">> => E#venture_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, venture_archived_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #venture_archived_v1{
                venture_id = VentureId,
                archived_by = get_value(archived_by, Map, undefined),
                reason = get_value(reason, Map, undefined),
                archived_at = get_value(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_venture_id(venture_archived_v1()) -> binary().
get_venture_id(#venture_archived_v1{venture_id = V}) -> V.

-spec get_archived_by(venture_archived_v1()) -> binary() | undefined.
get_archived_by(#venture_archived_v1{archived_by = V}) -> V.

-spec get_reason(venture_archived_v1()) -> binary() | undefined.
get_reason(#venture_archived_v1{reason = V}) -> V.

-spec get_archived_at(venture_archived_v1()) -> integer().
get_archived_at(#venture_archived_v1{archived_at = V}) -> V.

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
