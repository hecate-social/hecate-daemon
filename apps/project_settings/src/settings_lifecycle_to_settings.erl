%%% @doc Merged projection: settings lifecycle events -> settings ETS.
%%%
%%% Handles settings_initiated_v1 and preferences_updated_v1 in a
%%% single projection to guarantee ordering.
%%% @end
-module(settings_lifecycle_to_settings).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, settings).
-define(KEY, settings).

interested_in() ->
    [<<"settings_initiated_v1">>,
     <<"preferences_updated_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"settings_initiated_v1">>   -> project_initiated(Data, State, RM);
        <<"preferences_updated_v1">>  -> project_preferences_updated(Data, State, RM);
        _                             -> {ok, State, RM}
    end.

%% --- Initiated: create settings entry ---

project_initiated(Data, State, RM) ->
    LinuxUser = gf(linux_user, Data),
    Hostname = gf(hostname, Data),
    HecateUserId = <<LinuxUser/binary, "@", Hostname/binary>>,
    Entry = #{
        linux_user     => LinuxUser,
        hostname       => Hostname,
        hecate_user_id => HecateUserId,
        preferences       => #{},
        status            => 1,
        status_label      => <<"Initialized">>,
        available_actions => [],
        initiated_at      => gf(initiated_at, Data)
    },
    {ok, RM2} = evoq_read_model:put(?KEY, Entry, RM),
    {ok, State, RM2}.

%% --- Preferences updated: merge into existing ---

project_preferences_updated(Data, State, RM) ->
    NewPrefs = gf(preferences, Data),
    case ets:lookup(?TABLE, ?KEY) of
        [{_, Existing}] ->
            CurrentPrefs = maps:get(preferences, Existing, #{}),
            Merged = merge_prefs(CurrentPrefs, NewPrefs),
            Updated = Existing#{preferences => Merged},
            {ok, RM2} = evoq_read_model:put(?KEY, Updated, RM),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Internal ---

merge_prefs(Current, New) when is_map(Current), is_map(New) ->
    maps:merge(Current, New);
merge_prefs(_Current, New) when is_map(New) ->
    New;
merge_prefs(Current, _New) ->
    Current.

get_event_type(#{event_type := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
