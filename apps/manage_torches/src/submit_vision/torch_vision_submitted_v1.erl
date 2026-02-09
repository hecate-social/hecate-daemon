%%% @doc torch_vision_submitted_v1 event
%%% Emitted when a torch's vision is finalized, completing DnA.
-module(torch_vision_submitted_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_torch_id/1, get_submitted_by/1, get_submitted_at/1]).

-record(torch_vision_submitted_v1, {
    torch_id     :: binary(),
    submitted_by :: binary() | undefined,
    submitted_at :: integer()
}).

-export_type([torch_vision_submitted_v1/0]).
-opaque torch_vision_submitted_v1() :: #torch_vision_submitted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> torch_vision_submitted_v1().
new(#{torch_id := TorchId} = Params) ->
    #torch_vision_submitted_v1{
        torch_id = TorchId,
        submitted_by = maps:get(submitted_by, Params, undefined),
        submitted_at = erlang:system_time(millisecond)
    }.

-spec to_map(torch_vision_submitted_v1()) -> map().
to_map(#torch_vision_submitted_v1{} = E) ->
    #{
        <<"event_type">> => <<"torch_vision_submitted_v1">>,
        <<"torch_id">> => E#torch_vision_submitted_v1.torch_id,
        <<"submitted_by">> => E#torch_vision_submitted_v1.submitted_by,
        <<"submitted_at">> => E#torch_vision_submitted_v1.submitted_at
    }.

-spec from_map(map()) -> {ok, torch_vision_submitted_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    case TorchId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #torch_vision_submitted_v1{
                torch_id = TorchId,
                submitted_by = get_value(submitted_by, Map, undefined),
                submitted_at = get_value(submitted_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_torch_id(torch_vision_submitted_v1()) -> binary().
get_torch_id(#torch_vision_submitted_v1{torch_id = V}) -> V.

-spec get_submitted_by(torch_vision_submitted_v1()) -> binary() | undefined.
get_submitted_by(#torch_vision_submitted_v1{submitted_by = V}) -> V.

-spec get_submitted_at(torch_vision_submitted_v1()) -> integer().
get_submitted_at(#torch_vision_submitted_v1{submitted_at = V}) -> V.

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
