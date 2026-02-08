%%% @doc identify_cartwheel_v1 command
%%%
%%% Identifies a cartwheel (bounded context) within a torch.
%%% This is the parent (torch) declaring "I need a cartwheel called X".
%%% The cartwheel service will later INITIATE the actual cartwheel lifecycle.
%%%
%%% Pattern: Parent IDENTIFIES, child INITIATES.
%%% @end
-module(identify_cartwheel_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_torch_id/1, get_context_name/1, get_description/1, get_identified_by/1]).
-export([generate_cartwheel_id/0]).

-record(identify_cartwheel_v1, {
    torch_id      :: binary(),
    context_name  :: binary(),
    description   :: binary() | undefined,
    identified_by :: binary() | undefined
}).

-export_type([identify_cartwheel_v1/0]).
-opaque identify_cartwheel_v1() :: #identify_cartwheel_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, identify_cartwheel_v1()} | {error, term()}.
new(#{torch_id := TorchId, context_name := ContextName} = Params) ->
    {ok, #identify_cartwheel_v1{
        torch_id = TorchId,
        context_name = ContextName,
        description = maps:get(description, Params, undefined),
        identified_by = maps:get(identified_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(identify_cartwheel_v1()) -> {ok, identify_cartwheel_v1()} | {error, term()}.
validate(#identify_cartwheel_v1{torch_id = TorchId}) when
    not is_binary(TorchId); byte_size(TorchId) =:= 0 ->
    {error, invalid_torch_id};
validate(#identify_cartwheel_v1{context_name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_context_name};
validate(#identify_cartwheel_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(identify_cartwheel_v1()) -> map().
to_map(#identify_cartwheel_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"identify_cartwheel">>,
        <<"torch_id">> => Cmd#identify_cartwheel_v1.torch_id,
        <<"context_name">> => Cmd#identify_cartwheel_v1.context_name,
        <<"description">> => Cmd#identify_cartwheel_v1.description,
        <<"identified_by">> => Cmd#identify_cartwheel_v1.identified_by
    }.

-spec from_map(map()) -> {ok, identify_cartwheel_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    ContextName = get_value(context_name, Map),
    Description = get_value(description, Map, undefined),
    IdentifiedBy = get_value(identified_by, Map, undefined),
    case {TorchId, ContextName} of
        {undefined, _} -> {error, missing_torch_id};
        {_, undefined} -> {error, missing_context_name};
        _ ->
            {ok, #identify_cartwheel_v1{
                torch_id = TorchId,
                context_name = ContextName,
                description = Description,
                identified_by = IdentifiedBy
            }}
    end.

%% Accessors
-spec get_torch_id(identify_cartwheel_v1()) -> binary().
get_torch_id(#identify_cartwheel_v1{torch_id = V}) -> V.

-spec get_context_name(identify_cartwheel_v1()) -> binary().
get_context_name(#identify_cartwheel_v1{context_name = V}) -> V.

-spec get_description(identify_cartwheel_v1()) -> binary() | undefined.
get_description(#identify_cartwheel_v1{description = V}) -> V.

-spec get_identified_by(identify_cartwheel_v1()) -> binary() | undefined.
get_identified_by(#identify_cartwheel_v1{identified_by = V}) -> V.

%% @doc Generate a unique cartwheel ID
-spec generate_cartwheel_id() -> binary().
generate_cartwheel_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"cw-", Ts/binary, "-", Rand/binary>>.

%% Internal helper
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
