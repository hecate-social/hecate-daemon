%%% @doc initiate_division_v1 command
%%% Initiates a new division within a venture.
-module(initiate_division_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_venture_id/1, get_context_name/1, get_initiated_by/1]).
-export([generate_id/0]).

-record(initiate_division_v1, {
    division_id  :: binary(),
    venture_id   :: binary(),
    context_name :: binary(),
    initiated_by :: binary() | undefined
}).

-export_type([initiate_division_v1/0]).
-opaque initiate_division_v1() :: #initiate_division_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_division_v1()} | {error, term()}.
new(#{venture_id := VentureId, context_name := ContextName} = Params) ->
    DivisionId = maps:get(division_id, Params, generate_id()),
    {ok, #initiate_division_v1{
        division_id = DivisionId,
        venture_id = VentureId,
        context_name = ContextName,
        initiated_by = maps:get(initiated_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_division_v1()) -> {ok, initiate_division_v1()} | {error, term()}.
validate(#initiate_division_v1{venture_id = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_venture_id};
validate(#initiate_division_v1{context_name = C}) when
    not is_binary(C); byte_size(C) =:= 0 ->
    {error, invalid_context_name};
validate(#initiate_division_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_division_v1()) -> map().
to_map(#initiate_division_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"initiate_division">>,
        <<"division_id">> => Cmd#initiate_division_v1.division_id,
        <<"venture_id">> => Cmd#initiate_division_v1.venture_id,
        <<"context_name">> => Cmd#initiate_division_v1.context_name,
        <<"initiated_by">> => Cmd#initiate_division_v1.initiated_by
    }.

-spec from_map(map()) -> {ok, initiate_division_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    ContextName = get_value(context_name, Map),
    DivisionId = get_value(division_id, Map, generate_id()),
    InitiatedBy = get_value(initiated_by, Map, undefined),
    case {VentureId, ContextName} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #initiate_division_v1{
                division_id = DivisionId,
                venture_id = VentureId,
                context_name = ContextName,
                initiated_by = InitiatedBy
            }}
    end.

%% Accessors
-spec get_division_id(initiate_division_v1()) -> binary().
get_division_id(#initiate_division_v1{division_id = V}) -> V.

-spec get_venture_id(initiate_division_v1()) -> binary().
get_venture_id(#initiate_division_v1{venture_id = V}) -> V.

-spec get_context_name(initiate_division_v1()) -> binary().
get_context_name(#initiate_division_v1{context_name = V}) -> V.

-spec get_initiated_by(initiate_division_v1()) -> binary() | undefined.
get_initiated_by(#initiate_division_v1{initiated_by = V}) -> V.

%% @doc Generate a unique division ID
-spec generate_id() -> binary().
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"division-", Ts/binary, "-", Rand/binary>>.

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
