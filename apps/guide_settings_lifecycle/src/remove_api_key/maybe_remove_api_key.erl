%%% @doc Handler for remove_api_key command
-module(maybe_remove_api_key).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{provider := Provider} = Payload) ->
    RemovedAt = maps:get(removed_at, Payload, erlang:system_time(millisecond)),
    Cmd = remove_api_key_v1:new(Provider, RemovedAt),
    handle(Cmd).

-spec handle(remove_api_key_v1:remove_api_key_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{provider := Provider, removed_at := RemovedAt} = remove_api_key_v1:to_map(Command),
    case byte_size(Provider) of
        0 -> {error, provider_required};
        _ ->
            Event = api_key_removed_v1:new(Provider, RemovedAt),
            {ok, [api_key_removed_v1:to_map(Event)]}
    end.

-spec dispatch(remove_api_key_v1:remove_api_key_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    StreamId = settings_aggregate:stream_id(),
    CmdMap = remove_api_key_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = remove_api_key,
        aggregate_type = settings_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => remove_api_key},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
