%%% @doc Handler for configure_api_key command
-module(maybe_configure_api_key).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{provider := Provider, api_key := ApiKey} = Payload) ->
    Label = maps:get(label, Payload, Provider),
    ConfiguredAt = maps:get(configured_at, Payload, erlang:system_time(millisecond)),
    Cmd = configure_api_key_v1:new(Provider, ApiKey, Label, ConfiguredAt),
    handle(Cmd).

-spec handle(configure_api_key_v1:configure_api_key_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{provider := Provider, api_key := ApiKey, label := Label,
      configured_at := ConfiguredAt} = configure_api_key_v1:to_map(Command),
    case validate(Provider, ApiKey) of
        ok ->
            Event = api_key_configured_v1:new(Provider, ApiKey, Label, ConfiguredAt),
            {ok, [api_key_configured_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(configure_api_key_v1:configure_api_key_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    StreamId = settings_aggregate:stream_id(),
    CmdMap = configure_api_key_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = configure_api_key,
        aggregate_type = settings_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => configure_api_key},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

%% Internal

validate(Provider, ApiKey) ->
    case {byte_size(Provider), byte_size(ApiKey)} of
        {0, _} -> {error, provider_required};
        {_, 0} -> {error, api_key_required};
        _ -> ok
    end.
