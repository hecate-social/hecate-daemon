%%% @doc Projection: preferences_updated_v1 -> settings table
-module(preferences_updated_v1_to_settings).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [init/1, terminate/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {subscription_id :: binary() | undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, SubId} = reckon_evoq_adapter:subscribe(
        hecate_event_store, event_type, <<"preferences_updated_v1">>,
        <<"prj_preferences_updated">>, #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{data = Data}}, State) ->
    project(Data),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> reckon_evoq_adapter:unsubscribe(hecate_event_store, SubId)
    end.

%% Internal

project(Data) ->
    NewPrefs = maps:get(<<"preferences">>, Data, maps:get(preferences, Data, #{})),
    NewPrefsJson = json:encode(NewPrefs),
    %% Read current preferences, merge, write back
    case project_settings_store:query("SELECT preferences FROM settings WHERE id = 1") of
        {ok, [[CurrentJson]]} ->
            Current = try json:decode(CurrentJson) catch _:_ -> #{} end,
            Merged = maps:merge(Current, NewPrefs),
            MergedJson = json:encode(Merged),
            Sql = "UPDATE settings SET preferences = ?1 WHERE id = 1",
            project_settings_store:execute(Sql, [MergedJson]);
        _ ->
            %% No row yet — store directly (shouldn't happen if initiated)
            Sql = "UPDATE settings SET preferences = ?1 WHERE id = 1",
            project_settings_store:execute(Sql, [NewPrefsJson])
    end.
