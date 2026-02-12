%%% @doc division_archived_v1 event
%%% Emitted when a division is archived (soft deleted).
-module(division_archived_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_reason/1, get_archived_at/1]).

-record(division_archived_v1, {
    division_id :: binary(),
    reason      :: binary() | undefined,
    archived_at :: integer()
}).

-export_type([division_archived_v1/0]).
-opaque division_archived_v1() :: #division_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> division_archived_v1().
new(#{division_id := DivisionId} = Params) ->
    #division_archived_v1{
        division_id = DivisionId,
        reason = maps:get(reason, Params, undefined),
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(division_archived_v1()) -> map().
to_map(#division_archived_v1{} = E) ->
    #{
        <<"event_type">> => <<"division_archived_v1">>,
        <<"division_id">> => E#division_archived_v1.division_id,
        <<"reason">> => E#division_archived_v1.reason,
        <<"archived_at">> => E#division_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, division_archived_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    case DivisionId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #division_archived_v1{
                division_id = DivisionId,
                reason = get_value(reason, Map, undefined),
                archived_at = get_value(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_division_id(division_archived_v1()) -> binary().
get_division_id(#division_archived_v1{division_id = V}) -> V.

-spec get_reason(division_archived_v1()) -> binary() | undefined.
get_reason(#division_archived_v1{reason = V}) -> V.

-spec get_archived_at(division_archived_v1()) -> integer().
get_archived_at(#division_archived_v1{archived_at = V}) -> V.

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
