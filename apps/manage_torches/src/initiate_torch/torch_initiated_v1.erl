%%% @doc torch_initiated_v1 event
%%% Emitted when a torch is successfully initiated.
-module(torch_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_torch_id/1, get_name/1, get_brief/1, get_initiated_by/1, get_initiated_at/1]).

-record(torch_initiated_v1, {
    torch_id     :: binary(),
    name         :: binary(),
    brief        :: binary() | undefined,
    initiated_by :: binary() | undefined,
    initiated_at :: integer()
}).

-export_type([torch_initiated_v1/0]).
-opaque torch_initiated_v1() :: #torch_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> torch_initiated_v1().
new(#{torch_id := TorchId, name := Name} = Params) ->
    #torch_initiated_v1{
        torch_id = TorchId,
        name = Name,
        brief = maps:get(brief, Params, undefined),
        initiated_by = maps:get(initiated_by, Params, undefined),
        initiated_at = erlang:system_time(millisecond)
    }.

-spec to_map(torch_initiated_v1()) -> map().
to_map(#torch_initiated_v1{} = E) ->
    #{
        <<"event_type">> => <<"torch_initiated_v1">>,
        <<"torch_id">> => E#torch_initiated_v1.torch_id,
        <<"name">> => E#torch_initiated_v1.name,
        <<"brief">> => E#torch_initiated_v1.brief,
        <<"initiated_by">> => E#torch_initiated_v1.initiated_by,
        <<"initiated_at">> => E#torch_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, torch_initiated_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    Name = get_value(name, Map),
    case {TorchId, Name} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #torch_initiated_v1{
                torch_id = TorchId,
                name = Name,
                brief = get_value(brief, Map, undefined),
                initiated_by = get_value(initiated_by, Map, undefined),
                initiated_at = get_value(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_torch_id(torch_initiated_v1()) -> binary().
get_torch_id(#torch_initiated_v1{torch_id = V}) -> V.

-spec get_name(torch_initiated_v1()) -> binary().
get_name(#torch_initiated_v1{name = V}) -> V.

-spec get_brief(torch_initiated_v1()) -> binary() | undefined.
get_brief(#torch_initiated_v1{brief = V}) -> V.

-spec get_initiated_by(torch_initiated_v1()) -> binary() | undefined.
get_initiated_by(#torch_initiated_v1{initiated_by = V}) -> V.

-spec get_initiated_at(torch_initiated_v1()) -> integer().
get_initiated_at(#torch_initiated_v1{initiated_at = V}) -> V.

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
