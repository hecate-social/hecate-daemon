%%% @doc archive_division_v1 command
%%% Archives a division (soft delete via compensating event).
-module(archive_division_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_reason/1]).

-record(archive_division_v1, {
    division_id :: binary(),
    reason      :: binary() | undefined
}).

-export_type([archive_division_v1/0]).
-opaque archive_division_v1() :: #archive_division_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_division_v1()} | {error, term()}.
new(#{division_id := DivisionId} = Params) ->
    {ok, #archive_division_v1{
        division_id = DivisionId,
        reason = maps:get(reason, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_division_v1()) -> {ok, archive_division_v1()} | {error, term()}.
validate(#archive_division_v1{division_id = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_division_id};
validate(#archive_division_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_division_v1()) -> map().
to_map(#archive_division_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"archive_division">>,
        <<"division_id">> => Cmd#archive_division_v1.division_id,
        <<"reason">> => Cmd#archive_division_v1.reason
    }.

-spec from_map(map()) -> {ok, archive_division_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    Reason = get_value(reason, Map, undefined),
    case DivisionId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_division_v1{
                division_id = DivisionId,
                reason = Reason
            }}
    end.

%% Accessors
-spec get_division_id(archive_division_v1()) -> binary().
get_division_id(#archive_division_v1{division_id = V}) -> V.

-spec get_reason(archive_division_v1()) -> binary() | undefined.
get_reason(#archive_division_v1{reason = V}) -> V.

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
