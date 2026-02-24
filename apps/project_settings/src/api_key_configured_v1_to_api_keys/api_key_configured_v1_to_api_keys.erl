%%% @doc Projection: api_key_configured_v1 -> api_keys table
-module(api_key_configured_v1_to_api_keys).
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
        hecate_event_store, event_type, <<"api_key_configured_v1">>,
        <<"prj_api_key_configured">>, #{start_from => 0, subscriber_pid => self()}
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
    Provider = maps:get(<<"provider">>, Data, maps:get(provider, Data, <<>>)),
    ApiKey = maps:get(<<"api_key">>, Data, maps:get(api_key, Data, <<>>)),
    Label = maps:get(<<"label">>, Data, maps:get(label, Data, Provider)),
    ConfiguredAt = maps:get(<<"configured_at">>, Data, maps:get(configured_at, Data, 0)),
    Sql = "INSERT OR REPLACE INTO api_keys (provider, api_key, label, configured_at)
           VALUES (?1, ?2, ?3, ?4)",
    project_settings_store:execute(Sql, [Provider, ApiKey, Label, ConfiguredAt]).
