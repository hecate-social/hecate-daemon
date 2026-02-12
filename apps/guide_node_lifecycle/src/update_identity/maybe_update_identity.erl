%%% @doc Handler for update_identity command
-module(maybe_update_identity).

-export([handle/1, handle_from_map/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle update_identity from a plain map payload.
-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{mri := MRI} = Payload) ->
    Metadata = maps:get(metadata, Payload, #{}),
    UpdatedAt = maps:get(updated_at, Payload, erlang:system_time(millisecond)),
    Cmd = update_identity_v1:new(MRI, Metadata, UpdatedAt),
    handle(Cmd).

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
        command_type = update_identity,
        aggregate_type = node_aggregate,
        aggregate_id = MRI,
        payload = CmdMap#{command_type => update_identity},
        metadata = #{timestamp => Timestamp}
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

