%%% @doc Projection: node_unpaired_v1 -> settings table
-module(node_unpaired_v1_to_settings).
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
        hecate_event_store, event_type, <<"node_unpaired_v1">>,
        <<"prj_node_unpaired">>, #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{data = _Data}}, State) ->
    project(),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> reckon_evoq_adapter:unsubscribe(hecate_event_store, SubId)
    end.

%% Internal

project() ->
    %% Revert hecate_user_id to user@host (no github)
    case project_settings_store:query("SELECT linux_user, hostname FROM settings WHERE id = 1") of
        {ok, [[LinuxUser, Hostname]]} ->
            HecateUserId = <<LinuxUser/binary, "@", Hostname/binary>>,
            Sql = "UPDATE settings SET github_user = NULL, realm = NULL, paired = 0,
                   paired_at = NULL, hecate_user_id = ?1, status = status & ~2 WHERE id = 1",
            project_settings_store:execute(Sql, [HecateUserId]);
        _ ->
            logger:warning("node_unpaired_v1 projection: settings row not found")
    end.
