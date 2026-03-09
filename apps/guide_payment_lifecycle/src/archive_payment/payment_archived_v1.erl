%%% @doc payment_archived_v1 event
%%% Emitted when a payment is archived (walking skeleton).
-module(payment_archived_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_payment_id/1, get_archived_at/1]).

-record(payment_archived_v1, {
    payment_id  :: binary(),
    archived_at :: integer()
}).

-export_type([payment_archived_v1/0]).
-opaque payment_archived_v1() :: #payment_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> payment_archived_v1().
new(#{payment_id := PaymentId}) ->
    #payment_archived_v1{
        payment_id = PaymentId,
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(payment_archived_v1()) -> map().
to_map(#payment_archived_v1{} = E) ->
    #{
        event_type => <<"payment_archived_v1">>,
        payment_id => E#payment_archived_v1.payment_id,
        archived_at => E#payment_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, payment_archived_v1()} | {error, term()}.
from_map(Map) ->
    PaymentId = hecate_api_utils:get_field(payment_id, Map),
    case PaymentId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #payment_archived_v1{
                payment_id = PaymentId,
                archived_at = hecate_api_utils:get_field(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_payment_id(payment_archived_v1()) -> binary().
get_payment_id(#payment_archived_v1{payment_id = V}) -> V.

-spec get_archived_at(payment_archived_v1()) -> integer().
get_archived_at(#payment_archived_v1{archived_at = V}) -> V.
