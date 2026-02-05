%%% @doc Listener for remote learning facts from mesh.
%%% Subscribes to hecate.learning.validated and projects to remote_learnings table.
-module(remote_learning_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    hecate_mesh_client:subscribe(<<"hecate.learning.validated">>, self()),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({mesh_fact, _Topic, Payload}, State) ->
    project_remote_learning(Payload),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% Internal

project_remote_learning(Payload) when is_map(Payload) ->
    Id = maps:get(<<"learning_id">>, Payload, maps:get(learning_id, Payload, generate_id())),
    SourceAgent = maps:get(<<"submitter_id">>, Payload, maps:get(submitter_id, Payload, <<"unknown">>)),
    Category = maps:get(<<"category">>, Payload, maps:get(category, Payload, undefined)),
    Domain = maps:get(<<"domain">>, Payload, maps:get(domain, Payload, undefined)),
    Title = maps:get(<<"title">>, Payload, maps:get(title, Payload, undefined)),
    LearningData = jsx:encode(Payload),
    Now = erlang:system_time(millisecond),

    Sql = "INSERT OR IGNORE INTO remote_learnings "
          "(id, source_agent, category, domain, title, learning_data, discovered_at, applied) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 0)",
    query_mentors_store:execute(Sql, [Id, SourceAgent, Category, Domain, Title, LearningData, Now]);
project_remote_learning(_) ->
    ok.

generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"remote-lrn-", Ts/binary, "-", Rand/binary>>.
