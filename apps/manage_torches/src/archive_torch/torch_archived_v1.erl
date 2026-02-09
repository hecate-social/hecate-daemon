%%% @doc torch_archived_v1 event
%%% Emitted when a torch is archived (soft deleted).
-module(torch_archived_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_torch_id/1, get_archived_by/1, get_reason/1, get_archived_at/1]).

-record(torch_archived_v1, {
    torch_id    :: binary(),
    archived_by :: binary() | undefined,
    reason      :: binary() | undefined,
    archived_at :: integer()
}).

-export_type([torch_archived_v1/0]).
-opaque torch_archived_v1() :: #torch_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> torch_archived_v1().
new(#{torch_id := TorchId} = Params) ->
    #torch_archived_v1{
        torch_id = TorchId,
        archived_by = maps:get(archived_by, Params, undefined),
        reason = maps:get(reason, Params, undefined),
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(torch_archived_v1()) -> map().
to_map(#torch_archived_v1{} = E) ->
    #{
        <<"event_type">> => <<"torch_archived_v1">>,
        <<"torch_id">> => E#torch_archived_v1.torch_id,
        <<"archived_by">> => E#torch_archived_v1.archived_by,
        <<"reason">> => E#torch_archived_v1.reason,
        <<"archived_at">> => E#torch_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, torch_archived_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    case TorchId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #torch_archived_v1{
                torch_id = TorchId,
                archived_by = get_value(archived_by, Map, undefined),
                reason = get_value(reason, Map, undefined),
                archived_at = get_value(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_torch_id(torch_archived_v1()) -> binary().
get_torch_id(#torch_archived_v1{torch_id = V}) -> V.

-spec get_archived_by(torch_archived_v1()) -> binary() | undefined.
get_archived_by(#torch_archived_v1{archived_by = V}) -> V.

-spec get_reason(torch_archived_v1()) -> binary() | undefined.
get_reason(#torch_archived_v1{reason = V}) -> V.

-spec get_archived_at(torch_archived_v1()) -> integer().
get_archived_at(#torch_archived_v1{archived_at = V}) -> V.

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
