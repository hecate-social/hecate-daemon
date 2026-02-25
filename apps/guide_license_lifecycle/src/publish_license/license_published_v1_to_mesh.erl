%%% @doc Emitter: license_published_v1 -> mesh (external pub/sub)
%%% Subscribes to licenses_store via evoq, publishes to Macula mesh.
-module(license_published_v1_to_mesh).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"license_published_v1">>).
-define(SUB_NAME, <<"license_published_v1_to_mesh">>).
-define(STORE_ID, licenses_store).
-define(MESH_TOPIC, <<"appstore.plugin_published">>).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(E) ->
        EventMap = ensure_map(E),
        hecate_mesh:publish(?MESH_TOPIC, EventMap)
    end, Events),
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

ensure_map(E) when is_map(E) -> E;
ensure_map(_) -> #{}.
