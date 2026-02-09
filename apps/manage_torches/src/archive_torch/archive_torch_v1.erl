%%% @doc archive_torch_v1 command
%%% Archives an existing torch (soft delete via compensating event).
-module(archive_torch_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_torch_id/1, get_archived_by/1, get_reason/1]).

-record(archive_torch_v1, {
    torch_id    :: binary(),
    archived_by :: binary() | undefined,
    reason      :: binary() | undefined
}).

-export_type([archive_torch_v1/0]).
-opaque archive_torch_v1() :: #archive_torch_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_torch_v1()} | {error, term()}.
new(#{torch_id := TorchId} = Params) ->
    {ok, #archive_torch_v1{
        torch_id = TorchId,
        archived_by = maps:get(archived_by, Params, undefined),
        reason = maps:get(reason, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_torch_v1()) -> {ok, archive_torch_v1()} | {error, term()}.
validate(#archive_torch_v1{torch_id = TorchId}) when
    not is_binary(TorchId); byte_size(TorchId) =:= 0 ->
    {error, invalid_torch_id};
validate(#archive_torch_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_torch_v1()) -> map().
to_map(#archive_torch_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"archive_torch">>,
        <<"torch_id">> => Cmd#archive_torch_v1.torch_id,
        <<"archived_by">> => Cmd#archive_torch_v1.archived_by,
        <<"reason">> => Cmd#archive_torch_v1.reason
    }.

-spec from_map(map()) -> {ok, archive_torch_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    ArchivedBy = get_value(archived_by, Map, undefined),
    Reason = get_value(reason, Map, undefined),
    case TorchId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_torch_v1{
                torch_id = TorchId,
                archived_by = ArchivedBy,
                reason = Reason
            }}
    end.

%% Accessors
-spec get_torch_id(archive_torch_v1()) -> binary().
get_torch_id(#archive_torch_v1{torch_id = V}) -> V.

-spec get_archived_by(archive_torch_v1()) -> binary() | undefined.
get_archived_by(#archive_torch_v1{archived_by = V}) -> V.

-spec get_reason(archive_torch_v1()) -> binary() | undefined.
get_reason(#archive_torch_v1{reason = V}) -> V.

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
