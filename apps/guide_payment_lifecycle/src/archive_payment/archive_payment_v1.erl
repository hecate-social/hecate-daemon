%%% @doc archive_payment_v1 command
%%% Archives a payment (walking skeleton).
-module(archive_payment_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_payment_id/1]).

-record(archive_payment_v1, {
    payment_id :: binary()
}).

-export_type([archive_payment_v1/0]).
-opaque archive_payment_v1() :: #archive_payment_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_payment_v1()} | {error, term()}.
command_type() -> archive_payment_v1.

new(#{payment_id := PaymentId}) ->
    {ok, #archive_payment_v1{
        payment_id = PaymentId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_payment_v1()) -> {ok, archive_payment_v1()} | {error, term()}.
validate(#archive_payment_v1{payment_id = PaymentId}) when
    not is_binary(PaymentId); byte_size(PaymentId) =:= 0 ->
    {error, invalid_payment_id};
validate(#archive_payment_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_payment_v1()) -> map().
to_map(#archive_payment_v1{} = Cmd) ->
    #{
        command_type => <<"archive_payment">>,
        payment_id => Cmd#archive_payment_v1.payment_id
    }.

-spec from_map(map()) -> {ok, archive_payment_v1()} | {error, term()}.
from_map(Map) ->
    PaymentId = hecate_api_utils:get_field(payment_id, Map),
    case PaymentId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_payment_v1{
                payment_id = PaymentId
            }}
    end.

%% Accessors
-spec get_payment_id(archive_payment_v1()) -> binary().
get_payment_id(#archive_payment_v1{payment_id = V}) -> V.
