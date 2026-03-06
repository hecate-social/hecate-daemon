%%% @doc maybe_initialize_launcher handler
%%% Business logic for initializing the launcher singleton.
%%% Creates default groups (SYSTEM with node, llm, appstore).
-module(maybe_initialize_launcher).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/0, dispatch_silent/0]).

%% @doc Handle initialize_launcher_v1 command (business logic only)
-spec handle(initialize_launcher_v1:initialize_launcher_v1()) ->
    {ok, [launcher_initialized_v1:launcher_initialized_v1()]} | {error, term()}.
handle(_Cmd) ->
    handle(_Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(initialize_launcher_v1:initialize_launcher_v1(), term()) ->
    {ok, [launcher_initialized_v1:launcher_initialized_v1()]} | {error, term()}.
handle(_Cmd, _State) ->
    Event = launcher_initialized_v1:new(#{
        groups => default_groups()
    }),
    {ok, [Event]}.

%% @doc Dispatch command via evoq (singleton, no args needed)
-spec dispatch() -> {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch() ->
    {ok, Cmd} = initialize_launcher_v1:new(#{}),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initialize_launcher,
        aggregate_type = launcher_aggregate,
        aggregate_id = <<"launcher">>,
        payload = initialize_launcher_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => launcher_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => launcher_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% @doc Dispatch silently, returning the result without raising on already_initialized
-spec dispatch_silent() -> {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch_silent() ->
    dispatch().

%% --- Internal ---

default_groups() ->
    [#{
        name => <<"SYSTEM">>,
        icon => <<"\xE2\x9A\x99\xEF\xB8\x8F">>,
        collapsed => false,
        apps => [<<"node">>, <<"llm">>, <<"appstore">>]
    }].
