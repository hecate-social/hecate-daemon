%%% @doc archive_venture_v1 command
%%% Archives an existing venture (soft delete via compensating event).
-module(archive_venture_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_reason/1]).

-record(archive_venture_v1, {
    venture_id :: binary(),
    reason     :: binary() | undefined
}).

-export_type([archive_venture_v1/0]).
-opaque archive_venture_v1() :: #archive_venture_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_venture_v1()} | {error, term()}.
new(#{venture_id := VentureId} = Params) ->
    {ok, #archive_venture_v1{
        venture_id = VentureId,
        reason = maps:get(reason, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_venture_v1()) -> {ok, archive_venture_v1()} | {error, term()}.
validate(#archive_venture_v1{venture_id = VentureId}) when
    not is_binary(VentureId); byte_size(VentureId) =:= 0 ->
    {error, invalid_venture_id};
validate(#archive_venture_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_venture_v1()) -> map().
to_map(#archive_venture_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"archive_venture">>,
        <<"venture_id">> => Cmd#archive_venture_v1.venture_id,
        <<"reason">> => Cmd#archive_venture_v1.reason
    }.

-spec from_map(map()) -> {ok, archive_venture_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    Reason = get_value(reason, Map, undefined),
    case VentureId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_venture_v1{
                venture_id = VentureId,
                reason = Reason
            }}
    end.

%% Accessors
-spec get_venture_id(archive_venture_v1()) -> binary().
get_venture_id(#archive_venture_v1{venture_id = V}) -> V.

-spec get_reason(archive_venture_v1()) -> binary() | undefined.
get_reason(#archive_venture_v1{reason = V}) -> V.

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
