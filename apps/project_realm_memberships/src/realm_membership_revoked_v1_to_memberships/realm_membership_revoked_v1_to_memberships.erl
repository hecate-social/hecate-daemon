%%% @doc Projection: realm_membership_revoked_v1 -> realm_memberships table
-module(realm_membership_revoked_v1_to_memberships).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [init/1, terminate/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {subscription_id :: binary() | undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, SubId} = evoq_subscriptions:subscribe(
        realm_memberships_store, event_type, <<"realm_membership_revoked_v1">>,
        <<"prj_rm_revoked">>, #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(#evoq_event{data = Data}) ->
        project(Data)
    end, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> evoq_subscriptions:unsubscribe(realm_memberships_store, SubId)
    end.

%% Internal

project(Data) ->
    MembershipId = maps:get(<<"membership_id">>, Data, maps:get(membership_id, Data, <<>>)),
    RevokedAt = maps:get(<<"revoked_at">>, Data, maps:get(revoked_at, Data, 0)),
    Sql = "UPDATE realm_memberships SET
           status = 'revoked', revoked_at = ?1
           WHERE membership_id = ?2",
    project_realm_memberships_store:execute(Sql, [RevokedAt, MembershipId]).
