%%% @doc unregister_entry_v1 command
%%% Removes an app entry from the launcher sidebar.
-module(unregister_entry_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_entry_id/1]).

-record(unregister_entry_v1, {
    entry_id :: binary()
}).

-export_type([unregister_entry_v1/0]).
-opaque unregister_entry_v1() :: #unregister_entry_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, unregister_entry_v1()} | {error, term()}.
new(#{entry_id := EntryId}) ->
    {ok, #unregister_entry_v1{
        entry_id = EntryId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(unregister_entry_v1()) -> {ok, unregister_entry_v1()} | {error, term()}.
validate(#unregister_entry_v1{entry_id = EntryId}) when
    not is_binary(EntryId); byte_size(EntryId) =:= 0 ->
    {error, invalid_entry_id};
validate(#unregister_entry_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(unregister_entry_v1()) -> map().
to_map(#unregister_entry_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"unregister_entry">>,
        <<"entry_id">>     => Cmd#unregister_entry_v1.entry_id
    }.

-spec from_map(map()) -> {ok, unregister_entry_v1()} | {error, term()}.
from_map(Map) ->
    EntryId = get_value(entry_id, Map),
    case EntryId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #unregister_entry_v1{
                entry_id = EntryId
            }}
    end.

%% Accessors
-spec get_entry_id(unregister_entry_v1()) -> binary().
get_entry_id(#unregister_entry_v1{entry_id = V}) -> V.

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
