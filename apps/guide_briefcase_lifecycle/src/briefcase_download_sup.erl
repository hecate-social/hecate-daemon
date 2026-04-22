%%% @doc simple_one_for_one supervisor for async download workers.
%%%
%%% One child per in-flight download. The PM
%%% `on_file_download_started_fetch_bytes` calls
%%% `start_worker/2,3` per `file_download_started_v1` event.
%%% Transient restart so workers that complete normally don't
%%% auto-restart, but crashed workers do (once, then the
%%% fail_file_download path takes over).
%%% @end
-module(briefcase_download_sup).
-behaviour(supervisor).

-export([start_link/0, start_worker/2, start_worker/3]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec start_worker(binary(), binary()) -> {ok, pid()} | {error, term()}.
start_worker(FileId, Realm) ->
    supervisor:start_child(?MODULE, [FileId, Realm]).

-spec start_worker(binary(), binary(), fun()) -> {ok, pid()} | {error, term()}.
start_worker(FileId, Realm, FetchFn) ->
    supervisor:start_child(?MODULE, [FileId, Realm, FetchFn]).

init([]) ->
    SupFlags = #{
        strategy  => simple_one_for_one,
        intensity => 10,
        period    => 10
    },
    Child = #{
        id       => briefcase_download_worker,
        start    => {briefcase_download_worker, start_link, []},
        restart  => transient,
        shutdown => 5000,
        type     => worker,
        modules  => [briefcase_download_worker]
    },
    {ok, {SupFlags, [Child]}}.
