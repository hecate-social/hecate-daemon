%%% @doc Handler for initiate_settings command
-module(maybe_initiate_settings).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{linux_user := LinuxUser, hostname := Hostname} = Payload) ->
    InitiatedAt = maps:get(initiated_at, Payload, erlang:system_time(millisecond)),
    Cmd = initiate_settings_v1:new(LinuxUser, Hostname, InitiatedAt),
    handle(Cmd).

-spec handle(initiate_settings_v1:initiate_settings_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{linux_user := LinuxUser, hostname := Hostname, initiated_at := InitiatedAt}
        = initiate_settings_v1:to_map(Command),
    case validate(LinuxUser, Hostname) of
        ok ->
            Event = settings_initiated_v1:new(LinuxUser, Hostname, InitiatedAt),
            {ok, [settings_initiated_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(initiate_settings_v1:initiate_settings_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    StreamId = settings_aggregate:stream_id(),
    CmdMap = initiate_settings_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = initiate_settings,
        aggregate_type = settings_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => initiate_settings},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => settings_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

%% Internal

validate(LinuxUser, Hostname) ->
    case {byte_size(LinuxUser), byte_size(Hostname)} of
        {0, _} -> {error, linux_user_required};
        {_, 0} -> {error, hostname_required};
        _ -> ok
    end.
