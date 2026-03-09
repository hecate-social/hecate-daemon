%%% @doc retract_offering_v1 command
%%% Pulls back an offering from the mesh.
-module(retract_offering_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_offering_id/1]).

-record(retract_offering_v1, {
    offering_id :: binary()
}).

-export_type([retract_offering_v1/0]).
-opaque retract_offering_v1() :: #retract_offering_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, retract_offering_v1()} | {error, term()}.
new(#{offering_id := OfferingId}) ->
    {ok, #retract_offering_v1{offering_id = OfferingId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(retract_offering_v1()) -> {ok, retract_offering_v1()} | {error, term()}.
validate(#retract_offering_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#retract_offering_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(retract_offering_v1()) -> map().
to_map(#retract_offering_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"retract_offering">>,
        <<"offering_id">> => Cmd#retract_offering_v1.offering_id
    }.

-spec from_map(map()) -> {ok, retract_offering_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, missing_required_fields};
        _ -> {ok, #retract_offering_v1{offering_id = OfferingId}}
    end.

-spec get_offering_id(retract_offering_v1()) -> binary().
get_offering_id(#retract_offering_v1{offering_id = V}) -> V.
