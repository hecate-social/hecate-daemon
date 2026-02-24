%%% @doc Projection: settings_initiated_v1 -> settings table
-module(settings_initiated_v1_to_settings).
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
        hecate_event_store, event_type, <<"settings_initiated_v1">>,
        <<"prj_settings_initiated">>, #{start_from => 0, subscriber_pid => self()}
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
    LinuxUser = maps:get(<<"linux_user">>, Data, maps:get(linux_user, Data, <<>>)),
    Hostname = maps:get(<<"hostname">>, Data, maps:get(hostname, Data, <<>>)),
    InitiatedAt = maps:get(<<"initiated_at">>, Data, maps:get(initiated_at, Data, 0)),
    HecateUserId = <<LinuxUser/binary, "@", Hostname/binary>>,
    Sql = "INSERT OR REPLACE INTO settings (id, linux_user, hostname, hecate_user_id, paired, preferences, status, initiated_at)
           VALUES (1, ?1, ?2, ?3, 0, '{}', 1, ?4)",
    project_settings_store:execute(Sql, [LinuxUser, Hostname, HecateUserId, InitiatedAt]).
