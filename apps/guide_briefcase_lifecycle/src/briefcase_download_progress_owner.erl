%%% @doc Tiny gen_server whose sole job is to own the progress ETS.
%%%
%%% The progress table needs to outlive any single worker but must
%%% disappear if the supervisor is torn down. Owning it from a
%%% supervised gen_server gives us that lifecycle without coupling
%%% it to any one worker.
%%% @end
-module(briefcase_download_progress_owner).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    briefcase_download_progress:ensure_table(),
    {ok, #{}}.

handle_call(_, _From, State) -> {reply, ok, State}.
handle_cast(_, State) -> {noreply, State}.
handle_info(_, State) -> {noreply, State}.
terminate(_, _) -> ok.
