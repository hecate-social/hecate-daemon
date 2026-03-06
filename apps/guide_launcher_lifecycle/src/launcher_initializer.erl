%%% @doc Launcher initializer.
%%%
%%% Simple gen_server that ensures the launcher aggregate is initialized
%%% on startup. Sends itself a delayed message, dispatches initialize_launcher_v1,
%%% then stops normally.
%%% @end
-module(launcher_initializer).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(INIT_DELAY_MS, 2000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    erlang:send_after(?INIT_DELAY_MS, self(), try_initialize),
    {ok, #{}}.

handle_info(try_initialize, State) ->
    case maybe_initialize_launcher:dispatch_silent() of
        {ok, _, _} ->
            logger:info("[launcher] Initialized launcher with default groups");
        {error, launcher_already_initialized} ->
            logger:info("[launcher] Launcher already initialized");
        {error, Reason} ->
            logger:warning("[launcher] Failed to initialize launcher: ~p", [Reason])
    end,
    {stop, normal, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
