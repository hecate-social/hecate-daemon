%%% @doc query_irc top-level supervisor
%%%
%%% Supervises:
%%% - SQLite store for IRC read models
%%% - Projections: channel_opened_v1 / channel_closed_v1 -> channels
%%% - Mesh listener: subscribe_to_mesh_channel_opened
%%% @end
-module(query_irc_sup).
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
        %% SQLite store (must start first)
        #{id => query_irc_store,
          start => {query_irc_store, start_link, []},
          restart => permanent, type => worker},

        %% Projections
        #{id => channel_opened_v1_to_channels,
          start => {channel_opened_v1_to_channels, start_link, []},
          restart => permanent, type => worker},
        #{id => channel_closed_v1_to_channels,
          start => {channel_closed_v1_to_channels, start_link, []},
          restart => permanent, type => worker},

        %% Mesh listener for remote channel announcements
        #{id => subscribe_to_mesh_channel_opened,
          start => {subscribe_to_mesh_channel_opened, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
