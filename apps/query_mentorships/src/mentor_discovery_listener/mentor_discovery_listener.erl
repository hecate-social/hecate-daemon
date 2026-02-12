%%% @doc Listener for remote mentor discovery facts from mesh.
%%% Subscribes to hecate.mentor.available and projects to remote_mentors table.
-module(mentor_discovery_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Delay subscription to allow mesh client to connect
    self() ! try_subscribe,
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(try_subscribe, State) ->
    case hecate_mesh_client:subscribe(<<"hecate.mentor.available">>, self()) of
        {ok, _} ->
            case hecate_mesh_client:subscribe(<<"hecate.mentor.withdrawn">>, self()) of
                {ok, _} ->
                    io:format("[mentor_discovery_listener] Subscribed to mentor topics~n"),
                    {noreply, State};
                {error, _} ->
                    erlang:send_after(5000, self(), try_subscribe),
                    {noreply, State}
            end;
        {error, not_connected} ->
            erlang:send_after(5000, self(), try_subscribe),
            {noreply, State};
        {error, _} ->
            erlang:send_after(5000, self(), try_subscribe),
            {noreply, State}
    end;
handle_info({mesh_fact, <<"hecate.mentor.available">>, Payload}, State) ->
    project_mentor_available(Payload),
    {noreply, State};
handle_info({mesh_fact, <<"hecate.mentor.withdrawn">>, Payload}, State) ->
    project_mentor_withdrawn(Payload),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% Internal

project_mentor_available(Payload) when is_map(Payload) ->
    AgentId = maps:get(<<"agent_id">>, Payload, maps:get(agent_id, Payload, undefined)),
    Domains = maps:get(<<"domains">>, Payload, maps:get(domains, Payload, [])),
    DomainsJson = jsx:encode(Domains),
    Now = erlang:system_time(millisecond),

    Sql = "INSERT INTO remote_mentors (agent_id, domains, discovered_at, last_seen_at) "
          "VALUES (?1, ?2, ?3, ?3) "
          "ON CONFLICT(agent_id) DO UPDATE SET "
          "domains = ?2, last_seen_at = ?3",
    query_mentorships_store:execute(Sql, [AgentId, DomainsJson, Now]);
project_mentor_available(_) ->
    ok.

project_mentor_withdrawn(Payload) when is_map(Payload) ->
    AgentId = maps:get(<<"agent_id">>, Payload, maps:get(agent_id, Payload, undefined)),
    Sql = "DELETE FROM remote_mentors WHERE agent_id = ?1",
    query_mentorships_store:execute(Sql, [AgentId]);
project_mentor_withdrawn(_) ->
    ok.
