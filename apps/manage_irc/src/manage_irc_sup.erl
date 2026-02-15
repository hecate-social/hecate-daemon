%%% @doc manage_irc top-level supervisor
%%%
%%% Supervises:
%%% - PG emitters for channel lifecycle events
%%% - Mesh emitters for channel announcements
%%% - Relay dynamic supervisor for per-channel message relays
%%% - Presence relay for mesh presence heartbeats
%%% @end
-module(manage_irc_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% ── PG emitters (internal) ──
        #{id => channel_opened_v1_to_pg,
          start => {channel_opened_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => channel_closed_v1_to_pg,
          start => {channel_closed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% ── Mesh emitters (external) ──
        #{id => channel_opened_v1_to_mesh,
          start => {channel_opened_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => channel_closed_v1_to_mesh,
          start => {channel_closed_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},

        %% ── Relay infrastructure ──
        #{id => relay_irc_message_sup,
          start => {relay_irc_message_sup, start_link, []},
          restart => permanent, type => supervisor},

        %% ── Presence relay (mesh -> pg) ──
        #{id => irc_presence_relay,
          start => {irc_presence_relay, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
