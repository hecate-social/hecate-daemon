%%% @doc IRC presence relay: mesh -> pg
%%%
%%% Subscribes to mesh topic hecate.irc.presence.
%%% When a remote presence heartbeat arrives, broadcasts to pg group
%%% irc_stream so all SSE handlers receive it.
%%% @end
-module(irc_presence_relay).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [init/1, terminate/2]}).

-record(state, {
    mesh_sub_ref :: reference() | undefined
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    SubRef = case hecate_mesh_client:subscribe(<<"hecate.irc.presence">>, self()) of
        {ok, Ref} -> Ref;
        {error, _} -> undefined
    end,
    logger:info("[irc_presence_relay] Started"),
    {ok, #state{mesh_sub_ref = SubRef}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({mesh_fact, _Topic, Payload}, State) ->
    %% Broadcast presence to all SSE stream handlers
    Members = pg:get_members(pg, irc_stream),
    lists:foreach(fun(Pid) -> Pid ! {irc_presence, Payload} end, Members),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{mesh_sub_ref = undefined}) ->
    ok;
terminate(_Reason, #state{mesh_sub_ref = SubRef}) ->
    hecate_mesh_client:unsubscribe(SubRef),
    ok.
