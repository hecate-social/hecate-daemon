%%% @doc maybe_define_dossier handler
%%% Business logic for defining a dossier during architecture and planning.
%%% Validates the command and dispatches via evoq.
-module(maybe_define_dossier).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle define_dossier_v1 command (business logic only)
-spec handle(define_dossier_v1:define_dossier_v1()) ->
    {ok, [dossier_defined_v1:dossier_defined_v1()]} | {error, term()}.
handle(Cmd) ->
    DossierName = define_dossier_v1:get_dossier_name(Cmd),
    case validate_command(DossierName) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(define_dossier_v1:define_dossier_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = define_dossier_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = define_dossier,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = define_dossier_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => cartwheel_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_cartwheels_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(DossierName) when is_binary(DossierName), byte_size(DossierName) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    dossier_defined_v1:new(#{
        cartwheel_id => define_dossier_v1:get_cartwheel_id(Cmd),
        dossier_id => define_dossier_v1:get_dossier_id(Cmd),
        dossier_name => define_dossier_v1:get_dossier_name(Cmd),
        stream_pattern => define_dossier_v1:get_stream_pattern(Cmd),
        description => define_dossier_v1:get_description(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
