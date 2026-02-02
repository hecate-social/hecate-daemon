%%% @doc Handler for update_identity command
-module(maybe_update_identity).

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle update_identity command - validates and creates identity_updated event.
-spec handle(update_identity_v1:update_identity_v1()) -> {ok, [map()]} | {error, mri_required}.
handle(Command) ->
    #{mri := MRI, metadata := Metadata, updated_at := UpdatedAt} = update_identity_v1:to_map(Command),

    case validate_update(MRI, Metadata) of
        ok ->
            Event = identity_updated_v1:new(MRI, Metadata, UpdatedAt),
            {ok, [identity_updated_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-spec validate_update(binary(), map()) -> ok | {error, mri_required}.
validate_update(MRI, _Metadata) ->
    %% Metadata is always a map per type spec
    case byte_size(MRI) of
        0 -> {error, mri_required};
        _ -> ok
    end.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice).
-spec dispatch(update_identity_v1:update_identity_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    MRI = maps:get(mri, update_identity_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = update_identity_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MRI, Timestamp),
        command_type = update_identity,
        aggregate_type = identity_aggregate,
        aggregate_id = MRI,
        payload = CmdMap#{command_type => update_identity},
        metadata = #{timestamp => Timestamp},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_identities_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(MRI, Ts) ->
    Hash = crypto:hash(sha256, <<MRI/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-update_identity-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
