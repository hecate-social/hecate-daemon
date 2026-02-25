%%% @doc Projection: node_paired_v1 -> settings table
-module(node_paired_v1_to_settings).
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
        settings_store, event_type, <<"node_paired_v1">>,
        <<"prj_node_paired">>, #{start_from => 0, subscriber_pid => self()}
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
        _ -> reckon_evoq_adapter:unsubscribe(settings_store, SubId)
    end.

%% Internal

project(Data) ->
    GithubUser = maps:get(<<"github_user">>, Data, maps:get(github_user, Data, <<>>)),
    Realm = maps:get(<<"realm">>, Data, maps:get(realm, Data, <<>>)),
    PairedAt = maps:get(<<"paired_at">>, Data, maps:get(paired_at, Data, 0)),
    %% Build hecate_user_id: need current linux_user + hostname from settings row
    case project_settings_store:query("SELECT linux_user, hostname FROM settings WHERE id = 1") of
        {ok, [[LinuxUser, Hostname]]} ->
            HecateUserId = <<LinuxUser/binary, "@", Hostname/binary, "@", GithubUser/binary>>,
            Sql = "UPDATE settings SET github_user = ?1, realm = ?2, paired = 1, paired_at = ?3,
                   hecate_user_id = ?4, status = status | 2 WHERE id = 1",
            project_settings_store:execute(Sql, [GithubUser, Realm, PairedAt, HecateUserId]);
        _ ->
            logger:warning("node_paired_v1 projection: settings row not found")
    end.
