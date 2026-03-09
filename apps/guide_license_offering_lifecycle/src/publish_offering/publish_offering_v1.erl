%%% @doc publish_offering_v1 command
%%% Makes an offering available for purchase on the mesh.
-module(publish_offering_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_offering_id/1]).

-record(publish_offering_v1, {
    offering_id :: binary()
}).

-export_type([publish_offering_v1/0]).
-opaque publish_offering_v1() :: #publish_offering_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, publish_offering_v1()} | {error, term()}.
new(#{offering_id := OfferingId}) ->
    {ok, #publish_offering_v1{offering_id = OfferingId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(publish_offering_v1()) -> {ok, publish_offering_v1()} | {error, term()}.
validate(#publish_offering_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#publish_offering_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(publish_offering_v1()) -> map().
to_map(#publish_offering_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"publish_offering">>,
        <<"offering_id">> => Cmd#publish_offering_v1.offering_id
    }.

-spec from_map(map()) -> {ok, publish_offering_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, missing_required_fields};
        _ -> {ok, #publish_offering_v1{offering_id = OfferingId}}
    end.

-spec get_offering_id(publish_offering_v1()) -> binary().
get_offering_id(#publish_offering_v1{offering_id = V}) -> V.
