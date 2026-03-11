%%% @doc Merged projection: payment lifecycle -> payments ETS read model.
%%%
%%% Handles both payment_initiated_v1 and payment_archived_v1 in a single
%%% gen_server to guarantee ordering (no race conditions on the same table).
%%% @end
-module(payment_lifecycle_to_payments).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-include_lib("guide_payment_lifecycle/include/payment_status.hrl").

-define(TABLE, payments).

interested_in() -> [<<"payment_initiated_v1">>, <<"payment_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    EventType = hecate_api_utils:get_field(event_type, Data),
    project_event(EventType, Data, State, RM).

project_event(<<"payment_initiated_v1">>, Data, State, RM) ->
    PaymentId = gf(payment_id, Data),
    Entry = #{
        payment_id => PaymentId,
        consumer_id => gf(consumer_id, Data),
        procurement_id => gf(procurement_id, Data),
        offering_id => gf(offering_id, Data),
        plugin_id => gf(plugin_id, Data),
        amount_cents => gf(amount_cents, Data),
        currency => gf(currency, Data),
        status            => ?PAY_INITIATED,
        status_label      => <<"Initiated">>,
        available_actions => [<<"archive">>],
        initiated_at      => gf(initiated_at, Data),
        archived_at       => undefined
    },
    {ok, RM2} = evoq_read_model:put(PaymentId, Entry, RM),
    {ok, State, RM2};

project_event(<<"payment_archived_v1">>, Data, State, RM) ->
    PaymentId = gf(payment_id, Data),
    case evoq_read_model:get(PaymentId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                archived_at       => gf(archived_at, Data),
                status            => evoq_bit_flags:set(maps:get(status, Existing), ?PAY_ARCHIVED),
                status_label      => <<"Archived">>,
                available_actions => []
            },
            {ok, RM2} = evoq_read_model:put(PaymentId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end;

project_event(_Unknown, _Data, State, RM) ->
    {ok, State, RM}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
