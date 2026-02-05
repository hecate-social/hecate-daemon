%%% @doc maybe_inventory_spoke handler
%%% Business logic for inventorying a spoke within a dossier.
%%% Validates the command and dispatches via evoq.
-module(maybe_inventory_spoke).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle inventory_spoke_v1 command (business logic only)
-spec handle(inventory_spoke_v1:inventory_spoke_v1()) ->
    {ok, [spoke_inventoried_v1:spoke_inventoried_v1()]} | {error, term()}.
handle(Cmd) ->
    SpokeName = inventory_spoke_v1:get_spoke_name(Cmd),
    SpokeType = inventory_spoke_v1:get_spoke_type(Cmd),
    case validate_command(SpokeName, SpokeType) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(inventory_spoke_v1:inventory_spoke_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ProjectId = inventory_spoke_v1:get_project_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(ProjectId, Timestamp),
        command_type = inventory_spoke,
        aggregate_type = alc_aggregate,
        aggregate_id = <<"alc-", ProjectId/binary>>,
        payload = inventory_spoke_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => alc_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_alc_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(SpokeName, SpokeType) when
    is_binary(SpokeName), byte_size(SpokeName) > 0,
    is_binary(SpokeType), byte_size(SpokeType) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    spoke_inventoried_v1:new(#{
        project_id => inventory_spoke_v1:get_project_id(Cmd),
        spoke_id => inventory_spoke_v1:get_spoke_id(Cmd),
        spoke_name => inventory_spoke_v1:get_spoke_name(Cmd),
        spoke_type => inventory_spoke_v1:get_spoke_type(Cmd),
        priority => inventory_spoke_v1:get_priority(Cmd),
        dossier_id => inventory_spoke_v1:get_dossier_id(Cmd),
        description => inventory_spoke_v1:get_description(Cmd)
    }).

generate_command_id(ProjectId, Timestamp) ->
    Hash = crypto:hash(sha256, <<ProjectId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
