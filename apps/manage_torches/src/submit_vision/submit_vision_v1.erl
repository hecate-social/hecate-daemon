%%% @doc submit_vision_v1 command
%%% Marks torch vision as finalized, transitioning DnA to complete.
-module(submit_vision_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_torch_id/1, get_submitted_by/1]).

-record(submit_vision_v1, {
    torch_id     :: binary(),
    submitted_by :: binary() | undefined
}).

-export_type([submit_vision_v1/0]).
-opaque submit_vision_v1() :: #submit_vision_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, submit_vision_v1()} | {error, term()}.
new(#{torch_id := TorchId} = Params) ->
    {ok, #submit_vision_v1{
        torch_id = TorchId,
        submitted_by = maps:get(submitted_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(submit_vision_v1()) -> {ok, submit_vision_v1()} | {error, term()}.
validate(#submit_vision_v1{torch_id = TorchId}) when
    not is_binary(TorchId); byte_size(TorchId) =:= 0 ->
    {error, invalid_torch_id};
validate(#submit_vision_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(submit_vision_v1()) -> map().
to_map(#submit_vision_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"submit_vision">>,
        <<"torch_id">> => Cmd#submit_vision_v1.torch_id,
        <<"submitted_by">> => Cmd#submit_vision_v1.submitted_by
    }.

-spec from_map(map()) -> {ok, submit_vision_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    SubmittedBy = get_value(submitted_by, Map, undefined),
    case TorchId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #submit_vision_v1{
                torch_id = TorchId,
                submitted_by = SubmittedBy
            }}
    end.

%% Accessors
-spec get_torch_id(submit_vision_v1()) -> binary().
get_torch_id(#submit_vision_v1{torch_id = V}) -> V.

-spec get_submitted_by(submit_vision_v1()) -> binary() | undefined.
get_submitted_by(#submit_vision_v1{submitted_by = V}) -> V.

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
