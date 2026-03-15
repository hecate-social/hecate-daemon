%%% @doc archive_procurement_v1 command
%%% Archives a procurement (walking skeleton).
-module(archive_procurement_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_procurement_id/1]).

-record(archive_procurement_v1, {
    procurement_id :: binary()
}).

-export_type([archive_procurement_v1/0]).
-opaque archive_procurement_v1() :: #archive_procurement_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_procurement_v1()} | {error, term()}.
command_type() -> archive_procurement_v1.

new(#{procurement_id := ProcurementId}) ->
    {ok, #archive_procurement_v1{
        procurement_id = ProcurementId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_procurement_v1()) -> {ok, archive_procurement_v1()} | {error, term()}.
validate(#archive_procurement_v1{procurement_id = ProcurementId}) when
    not is_binary(ProcurementId); byte_size(ProcurementId) =:= 0 ->
    {error, invalid_procurement_id};
validate(#archive_procurement_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_procurement_v1()) -> map().
to_map(#archive_procurement_v1{} = Cmd) ->
    #{
        command_type => <<"archive_procurement">>,
        procurement_id => Cmd#archive_procurement_v1.procurement_id
    }.

-spec from_map(map()) -> {ok, archive_procurement_v1()} | {error, term()}.
from_map(Map) ->
    ProcurementId = hecate_api_utils:get_field(procurement_id, Map),
    case ProcurementId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_procurement_v1{
                procurement_id = ProcurementId
            }}
    end.

%% Accessors
-spec get_procurement_id(archive_procurement_v1()) -> binary().
get_procurement_id(#archive_procurement_v1{procurement_id = V}) -> V.
