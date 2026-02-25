%%% @doc Handler for update_preferences command
-module(maybe_update_preferences).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{preferences := Preferences} = Payload) when is_map(Preferences) ->
    UpdatedAt = maps:get(updated_at, Payload, erlang:system_time(millisecond)),
    Cmd = update_preferences_v1:new(Preferences, UpdatedAt),
    handle(Cmd);
handle_from_map(_) ->
    {error, preferences_must_be_map}.

-spec handle(update_preferences_v1:update_preferences_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{preferences := Preferences, updated_at := UpdatedAt}
        = update_preferences_v1:to_map(Command),
    case is_map(Preferences) of
        true ->
            Event = preferences_updated_v1:new(Preferences, UpdatedAt),
            {ok, [preferences_updated_v1:to_map(Event)]};
        false ->
            {error, preferences_must_be_map}
    end.

-spec dispatch(update_preferences_v1:update_preferences_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    StreamId = settings_aggregate:stream_id(),
    CmdMap = update_preferences_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = update_preferences,
        aggregate_type = settings_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => update_preferences},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => settings_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
