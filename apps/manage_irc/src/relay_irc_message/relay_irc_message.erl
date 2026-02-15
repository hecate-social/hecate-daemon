%%% @doc Per-channel IRC message relay.
%%%
%%% Subscribes to mesh topic hecate.irc.msg.{channel_id}.
%%% When a mesh message arrives, broadcasts to pg group {irc_msg, ChannelId}.
%%% SSE stream handlers join these pg groups to receive messages.
%%% @end
-module(relay_irc_message).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [init/1, terminate/2]}).

-record(state, {
    channel_id :: binary(),
    mesh_sub_ref :: reference() | undefined
}).

-spec start_link(binary()) -> {ok, pid()} | {error, term()}.
start_link(ChannelId) ->
    gen_server:start_link(?MODULE, [ChannelId], []).

init([ChannelId]) ->
    Topic = <<"hecate.irc.msg.", ChannelId/binary>>,
    SubRef = case hecate_mesh_client:subscribe(Topic, self()) of
        {ok, Ref} -> Ref;
        {error, _} -> undefined
    end,
    logger:info("[relay_irc_message] Started for channel ~s", [ChannelId]),
    {ok, #state{channel_id = ChannelId, mesh_sub_ref = SubRef}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Mesh message arrived — broadcast to local pg group
handle_info({mesh_fact, _Topic, Payload}, #state{channel_id = ChannelId} = State) ->
    PgGroup = {irc_msg, ChannelId},
    Members = pg:get_members(pg, PgGroup),
    Msg = {irc_msg, ChannelId, Payload},
    lists:foreach(fun(Pid) -> Pid ! Msg end, Members),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{mesh_sub_ref = undefined}) ->
    ok;
terminate(_Reason, #state{mesh_sub_ref = SubRef}) ->
    hecate_mesh_client:unsubscribe(SubRef),
    ok.
