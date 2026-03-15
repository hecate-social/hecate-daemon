%%% @doc archive_offering_v1 command
%%% Archives an offering (walking skeleton).
-module(archive_offering_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_offering_id/1]).

-record(archive_offering_v1, {
    offering_id :: binary()
}).

-export_type([archive_offering_v1/0]).
-opaque archive_offering_v1() :: #archive_offering_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_offering_v1()} | {error, term()}.
command_type() -> archive_offering_v1.

new(#{offering_id := OfferingId}) ->
    {ok, #archive_offering_v1{offering_id = OfferingId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_offering_v1()) -> {ok, archive_offering_v1()} | {error, term()}.
validate(#archive_offering_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#archive_offering_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_offering_v1()) -> map().
to_map(#archive_offering_v1{} = Cmd) ->
    #{
        command_type => <<"archive_offering">>,
        offering_id => Cmd#archive_offering_v1.offering_id
    }.

-spec from_map(map()) -> {ok, archive_offering_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, missing_required_fields};
        _ -> {ok, #archive_offering_v1{offering_id = OfferingId}}
    end.

-spec get_offering_id(archive_offering_v1()) -> binary().
get_offering_id(#archive_offering_v1{offering_id = V}) -> V.
