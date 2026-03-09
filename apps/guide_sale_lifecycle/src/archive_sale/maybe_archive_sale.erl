%%% @doc maybe_archive_sale handler
%%% Business logic for archiving sales.
-module(maybe_archive_sale).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle archive_sale_v1 command (business logic only)
-spec handle(archive_sale_v1:archive_sale_v1()) ->
    {ok, [sale_archived_v1:sale_archived_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(archive_sale_v1:archive_sale_v1(), term()) ->
    {ok, [sale_archived_v1:sale_archived_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    SaleId = archive_sale_v1:get_sale_id(Cmd),
    case validate_command(SaleId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(archive_sale_v1:archive_sale_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    SaleId = archive_sale_v1:get_sale_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = archive_sale,
        aggregate_type = sale_aggregate,
        aggregate_id = SaleId,
        payload = archive_sale_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => sale_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => sales_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(SaleId) when is_binary(SaleId), byte_size(SaleId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_sale_id}.

create_event(Cmd) ->
    sale_archived_v1:new(#{
        sale_id => archive_sale_v1:get_sale_id(Cmd)
    }).
