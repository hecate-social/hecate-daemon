%%% @doc Mesh projection: agent_unfollowed_v1 → Macula Mesh
-module(agent_unfollowed_v1_to_mesh).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {subscription_id :: binary() | undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, SubId} = reckon_evoq_adapter:subscribe(
        manage_social_store, event_type, <<"agent_unfollowed_v1">>,
        <<"mesh_agent_unfollowed">>, #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, State) ->
    hecate_mesh_publisher:publish_event(EventType, EventData),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> reckon_evoq_adapter:unsubscribe(manage_social_store, SubId)
    end.
