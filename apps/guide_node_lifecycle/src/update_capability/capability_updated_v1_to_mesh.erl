%%% @doc Mesh projection: capability_updated_v1 → Macula Mesh
%%% Projects capability updates to the mesh as integration facts.
-module(capability_updated_v1_to_mesh).
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
        hecate_event_store,
        event_type,
        <<"capability_updated_v1">>,
        <<"mesh_capability_updated">>,
        #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{data = EventData}}, State) ->
    %% Publish integration fact to mesh (this emitter owns its topic)
    hecate_mesh_client:publish(<<"hecate.capability.revised">>, EventData),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> reckon_evoq_adapter:unsubscribe(hecate_event_store, SubId)
    end.
