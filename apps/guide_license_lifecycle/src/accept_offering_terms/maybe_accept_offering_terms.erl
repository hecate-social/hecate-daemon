%%% @doc maybe_accept_offering_terms handler
%%% Business logic for accepting offering terms.
%%% Lightweight — just confirms consent. Echoes fee_cents from
%%% aggregate state so the auto-grant PM can decide free vs paid.
-module(maybe_accept_offering_terms).

-include_lib("evoq/include/evoq.hrl").
-include("license_state.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle accept_offering_terms_v1 command (business logic only)
-spec handle(accept_offering_terms_v1:accept_offering_terms_v1()) ->
    {ok, [offering_terms_accepted_v1:offering_terms_accepted_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern — receives aggregate state)
-spec handle(accept_offering_terms_v1:accept_offering_terms_v1(), term()) ->
    {ok, [offering_terms_accepted_v1:offering_terms_accepted_v1()]} | {error, term()}.
handle(Cmd, State) ->
    LicenseId = accept_offering_terms_v1:get_license_id(Cmd),
    case validate_command(LicenseId) of
        ok ->
            Event = create_event(Cmd, State),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(accept_offering_terms_v1:accept_offering_terms_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = accept_offering_terms_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = accept_offering_terms,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = accept_offering_terms_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => license_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => licenses_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(LicenseId) when is_binary(LicenseId), byte_size(LicenseId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_license_id}.

create_event(Cmd, #license_state{consumer_id = ConsumerId,
                                 offering_id = OfferingId,
                                 plugin_id   = PluginId,
                                 author_id   = AuthorId,
                                 fee_cents   = FeeCents}) ->
    offering_terms_accepted_v1:new(#{
        license_id  => accept_offering_terms_v1:get_license_id(Cmd),
        consumer_id => ConsumerId,
        offering_id => OfferingId,
        plugin_id   => PluginId,
        author_id   => AuthorId,
        fee_cents   => FeeCents
    });
create_event(Cmd, _) ->
    offering_terms_accepted_v1:new(#{
        license_id => accept_offering_terms_v1:get_license_id(Cmd)
    }).
