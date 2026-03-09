%%% @doc announce_offering_v1 command
%%% Pre-publish step: announces an offering for review.
-module(announce_offering_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_offering_id/1]).

-record(announce_offering_v1, {
    offering_id :: binary()
}).

-export_type([announce_offering_v1/0]).
-opaque announce_offering_v1() :: #announce_offering_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, announce_offering_v1()} | {error, term()}.
new(#{offering_id := OfferingId}) ->
    {ok, #announce_offering_v1{offering_id = OfferingId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(announce_offering_v1()) -> {ok, announce_offering_v1()} | {error, term()}.
validate(#announce_offering_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#announce_offering_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(announce_offering_v1()) -> map().
to_map(#announce_offering_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"announce_offering">>,
        <<"offering_id">> => Cmd#announce_offering_v1.offering_id
    }.

-spec from_map(map()) -> {ok, announce_offering_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, missing_required_fields};
        _ -> {ok, #announce_offering_v1{offering_id = OfferingId}}
    end.

-spec get_offering_id(announce_offering_v1()) -> binary().
get_offering_id(#announce_offering_v1{offering_id = V}) -> V.
