%%% @doc initiate_torch_v1 command
%%% Initiates a new torch (project) in the Torches domain.
-module(initiate_torch_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_torch_id/1, get_name/1, get_brief/1, get_initiated_by/1]).
-export([generate_id/0]).

-record(initiate_torch_v1, {
    torch_id     :: binary(),
    name         :: binary(),
    brief        :: binary() | undefined,
    initiated_by :: binary() | undefined
}).

-export_type([initiate_torch_v1/0]).
-opaque initiate_torch_v1() :: #initiate_torch_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_torch_v1()} | {error, term()}.
new(#{name := Name} = Params) ->
    TorchId = maps:get(torch_id, Params, generate_id()),
    {ok, #initiate_torch_v1{
        torch_id = TorchId,
        name = Name,
        brief = maps:get(brief, Params, undefined),
        initiated_by = maps:get(initiated_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_torch_v1()) -> {ok, initiate_torch_v1()} | {error, term()}.
validate(#initiate_torch_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#initiate_torch_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_torch_v1()) -> map().
to_map(#initiate_torch_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"initiate_torch">>,
        <<"torch_id">> => Cmd#initiate_torch_v1.torch_id,
        <<"name">> => Cmd#initiate_torch_v1.name,
        <<"brief">> => Cmd#initiate_torch_v1.brief,
        <<"initiated_by">> => Cmd#initiate_torch_v1.initiated_by
    }.

-spec from_map(map()) -> {ok, initiate_torch_v1()} | {error, term()}.
from_map(Map) ->
    %% Support both atom and binary keys
    Name = get_value(name, Map),
    TorchId = get_value(torch_id, Map, generate_id()),
    Brief = get_value(brief, Map, undefined),
    InitiatedBy = get_value(initiated_by, Map, undefined),
    case Name of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #initiate_torch_v1{
                torch_id = TorchId,
                name = Name,
                brief = Brief,
                initiated_by = InitiatedBy
            }}
    end.

%% Accessors
-spec get_torch_id(initiate_torch_v1()) -> binary().
get_torch_id(#initiate_torch_v1{torch_id = V}) -> V.

-spec get_name(initiate_torch_v1()) -> binary().
get_name(#initiate_torch_v1{name = V}) -> V.

-spec get_brief(initiate_torch_v1()) -> binary() | undefined.
get_brief(#initiate_torch_v1{brief = V}) -> V.

-spec get_initiated_by(initiate_torch_v1()) -> binary() | undefined.
get_initiated_by(#initiate_torch_v1{initiated_by = V}) -> V.

%% @doc Generate a unique torch ID
-spec generate_id() -> binary().
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"torch-", Ts/binary, "-", Rand/binary>>.

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
