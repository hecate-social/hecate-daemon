%%% @doc archive_sale_v1 command
%%% Archives a sale (walking skeleton).
-module(archive_sale_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_sale_id/1]).

-record(archive_sale_v1, {
    sale_id :: binary()
}).

-export_type([archive_sale_v1/0]).
-opaque archive_sale_v1() :: #archive_sale_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_sale_v1()} | {error, term()}.
command_type() -> archive_sale_v1.

new(#{sale_id := SaleId}) ->
    {ok, #archive_sale_v1{
        sale_id = SaleId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_sale_v1()) -> {ok, archive_sale_v1()} | {error, term()}.
validate(#archive_sale_v1{sale_id = SaleId}) when
    not is_binary(SaleId); byte_size(SaleId) =:= 0 ->
    {error, invalid_sale_id};
validate(#archive_sale_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_sale_v1()) -> map().
to_map(#archive_sale_v1{} = Cmd) ->
    #{
        command_type => <<"archive_sale">>,
        sale_id => Cmd#archive_sale_v1.sale_id
    }.

-spec from_map(map()) -> {ok, archive_sale_v1()} | {error, term()}.
from_map(Map) ->
    SaleId = hecate_api_utils:get_field(sale_id, Map),
    case SaleId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_sale_v1{
                sale_id = SaleId
            }}
    end.

%% Accessors
-spec get_sale_id(archive_sale_v1()) -> binary().
get_sale_id(#archive_sale_v1{sale_id = V}) -> V.
