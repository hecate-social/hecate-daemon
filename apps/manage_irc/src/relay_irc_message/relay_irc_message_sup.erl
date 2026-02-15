%%% @doc Dynamic supervisor for per-channel IRC message relays.
%%% Each channel gets a relay_irc_message gen_server that subscribes
%%% to mesh topic hecate.irc.msg.{channel_id} and broadcasts to pg.
-module(relay_irc_message_sup).
-behaviour(supervisor).

-export([start_link/0, ensure_relay/1, stop_relay/1]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },
    %% Children are started dynamically via ensure_relay/1
    {ok, {SupFlags, []}}.

%% @doc Ensure a relay exists for the given channel. Idempotent.
-spec ensure_relay(binary()) -> {ok, pid()} | {error, term()}.
ensure_relay(ChannelId) ->
    ChildId = {relay_irc_message, ChannelId},
    ChildSpec = #{
        id => ChildId,
        start => {relay_irc_message, start_link, [ChannelId]},
        restart => transient,
        type => worker
    },
    case supervisor:start_child(?MODULE, ChildSpec) of
        {ok, Pid} -> {ok, Pid};
        {error, {already_started, Pid}} -> {ok, Pid};
        {error, already_present} ->
            %% Child was stopped but spec remains; restart it
            supervisor:delete_child(?MODULE, ChildId),
            supervisor:start_child(?MODULE, ChildSpec);
        {error, Reason} -> {error, Reason}
    end.

%% @doc Stop a relay for the given channel.
-spec stop_relay(binary()) -> ok.
stop_relay(ChannelId) ->
    ChildId = {relay_irc_message, ChannelId},
    supervisor:terminate_child(?MODULE, ChildId),
    supervisor:delete_child(?MODULE, ChildId),
    ok.
