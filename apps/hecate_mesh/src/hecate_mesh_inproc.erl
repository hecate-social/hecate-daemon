%%%-------------------------------------------------------------------
%%% @doc In-process mesh backend for tests + inproc devtime.
%%%
%%% Implements the same public API as `hecate_mesh_client`, registered
%%% under the same local name — the supervisor picks one or the other
%%% based on `application:get_env(hecate, mesh_backend, client)`.
%%%
%%% Semantics:
%%%
%%%   publish/2 — synchronously fans out the payload to every
%%%     subscription whose topic equals the published topic. Each
%%%     subscriber callback runs in its own spawned process so a
%%%     slow/crashing callback does not block the publisher.
%%%
%%%   subscribe/2 — registers the callback against Topic, returns a
%%%     reference.
%%%
%%%   call/3,4 — looks up an advertised procedure by exact name and
%%%     invokes the handler inline. Returns `{error, not_advertised}`
%%%     for unknown procedures.
%%%
%%%   call_stream/4 — dispatches through macula's local stream fabric
%%%     (`macula:call_stream/2`). Advertisements are registered via
%%%     `macula:advertise_stream/3` so the real streaming code path
%%%     is exercised end-to-end — only the relay hop is bypassed.
%%%
%%%   activate/0 / is_activated/0 — always OK / true. Removes the
%%%     boot-race guard that callers wrap their subscription code in;
%%%     inproc mode is always "ready".
%%%
%%% Lifecycle:
%%%
%%%   Two ETS tables (`hecate_mesh_inproc_subs` + `hecate_mesh_inproc_advs`)
%%%   are created in init/1 and owned by this gen_server so they are
%%%   torn down automatically if the process crashes or is stopped.
%%%
%%% Selecting this backend:
%%%
%%%   Set `{hecate, [{mesh_backend, inproc}]}` in sys.config (or via
%%%   application env before hecate_mesh_sup starts). CT suites set
%%%   this in init_per_suite.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_mesh_inproc).
-behaviour(gen_server).

-export([start_link/0, activate/0, is_activated/0]).
-export([get_client/0, get_status/0,
         publish/2, subscribe/2, unsubscribe/1,
         advertise/2, call/3, call/4,
         discover_subscribers/1,
         register_subscription/2, register_advertisement/2,
         unregister_advertisement/1,
         register_stream_advertisement/3, call_stream/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Test/debug helpers
-export([dump_subscriptions/0, dump_advertisements/0, clear/0]).

-define(SUB_TABLE, hecate_mesh_inproc_subs).
-define(ADV_TABLE, hecate_mesh_inproc_advs).
-define(SERVER, hecate_mesh_client).   %% deliberately same name as real backend

-record(sub, {
    ref      :: reference(),
    topic    :: binary(),
    callback :: fun()
}).

-record(adv, {
    procedure :: binary(),
    handler   :: fun()
}).

%%====================================================================
%% API (mirrors hecate_mesh_client exactly)
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec activate() -> ok.
activate() -> ok.

-spec is_activated() -> boolean().
is_activated() -> true.

-spec get_client() -> {ok, pid()} | {error, term()}.
get_client() ->
    case erlang:whereis(?SERVER) of
        undefined -> {error, not_started};
        Pid       -> {ok, Pid}
    end.

-spec get_status() -> {ok, map()}.
get_status() ->
    {ok, #{
        backend        => inproc,
        activated      => true,
        multi_relay    => #{connections => []},
        subscriptions  => ets_size(?SUB_TABLE),
        advertisements => ets_size(?ADV_TABLE)
    }}.

-spec publish(binary(), term()) -> ok.
publish(Topic, Payload) when is_binary(Topic) ->
    ensure_table(?SUB_TABLE, [bag, public, named_table]),
    Subs = ets:match_object(?SUB_TABLE,
            {'_', #sub{ref = '_', topic = Topic, callback = '_'}}),
    lists:foreach(
        fun({_K, #sub{callback = Cb}}) ->
            spawn(fun() -> invoke_cb(Cb, #{topic => Topic, payload => Payload}) end)
        end, Subs),
    ok.

-spec subscribe(binary(), fun()) -> {ok, reference()}.
subscribe(Topic, Callback) when is_binary(Topic), is_function(Callback) ->
    ensure_table(?SUB_TABLE, [bag, public, named_table]),
    Ref = make_ref(),
    Sub = #sub{ref = Ref, topic = Topic, callback = Callback},
    ets:insert(?SUB_TABLE, {Ref, Sub}),
    {ok, Ref}.

-spec unsubscribe(reference()) -> ok.
unsubscribe(Ref) when is_reference(Ref) ->
    case ets:info(?SUB_TABLE) of
        undefined -> ok;
        _         -> ets:delete(?SUB_TABLE, Ref), ok
    end.

%% discover_subscribers is a mesh-wide peer query in production. In
%% inproc mode there's only us, so return our own subscriptions that
%% match the topic.
-spec discover_subscribers(binary()) -> {ok, [pid()]}.
discover_subscribers(Topic) ->
    ensure_table(?SUB_TABLE, [bag, public, named_table]),
    All = ets:match_object(?SUB_TABLE,
            {'_', #sub{ref = '_', topic = Topic, callback = '_'}}),
    {ok, [self() || _ <- All]}.

-spec advertise(binary(), fun()) -> {ok, reference()}.
advertise(Procedure, Handler) ->
    register_advertisement(Procedure, Handler),
    {ok, make_ref()}.

-spec call(binary(), term(), timeout()) -> {ok, term()} | {error, term()}.
call(Procedure, Args, Timeout) ->
    call(Procedure, Args, #{}, Timeout).

-spec call(binary(), term(), map(), timeout()) -> {ok, term()} | {error, term()}.
call(Procedure, Args, _Opts, _Timeout) when is_binary(Procedure) ->
    ensure_table(?ADV_TABLE, [set, public, named_table]),
    case ets:lookup(?ADV_TABLE, Procedure) of
        [{_, #adv{handler = Handler}}] ->
            safe_invoke_handler(Handler, Args);
        [] ->
            {error, not_advertised}
    end.

-spec register_subscription(binary(), fun()) -> ok.
register_subscription(Topic, Callback) ->
    _ = subscribe(Topic, Callback),
    ok.

-spec register_advertisement(binary(), fun()) -> ok.
register_advertisement(Procedure, Handler)
  when is_binary(Procedure), is_function(Handler) ->
    ensure_table(?ADV_TABLE, [set, public, named_table]),
    ets:insert(?ADV_TABLE, {Procedure, #adv{procedure = Procedure,
                                            handler   = Handler}}),
    ok.

-spec unregister_advertisement(binary()) -> ok.
unregister_advertisement(Procedure) when is_binary(Procedure) ->
    case ets:info(?ADV_TABLE) of
        undefined -> ok;
        _ ->
            ets:delete(?ADV_TABLE, Procedure),
            %% Also detach from macula's stream-local fabric if
            %% present — keeps the two surfaces consistent when tests
            %% re-advertise.
            safe_unadvertise_stream(Procedure),
            ok
    end.

%% Streaming advertisements go straight through macula_stream_local —
%% the real code path, minus any relay hop. This means Phase E's
%% stream_file_content_rpc is exercised end-to-end by in-VM tests.
-spec register_stream_advertisement(binary(), atom(),
        fun((pid(), term()) -> any())) -> ok.
register_stream_advertisement(Procedure, Mode, Handler)
  when is_binary(Procedure), is_atom(Mode), is_function(Handler) ->
    ok = ensure_macula_started(),
    _ = safe_unadvertise_stream(Procedure),
    case macula:advertise_stream(Procedure, Mode, Handler) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end.

-spec call_stream(binary(), term(), map(), timeout()) ->
    {ok, pid()} | {error, term()}.
call_stream(Procedure, Args, _Opts, _Timeout) ->
    ok = ensure_macula_started(),
    macula:call_stream(Procedure, Args).

%%====================================================================
%% Test / debug helpers
%%====================================================================

dump_subscriptions() ->
    ensure_table(?SUB_TABLE, [bag, public, named_table]),
    [{T, Cb} || {_K, #sub{topic = T, callback = Cb}} <- ets:tab2list(?SUB_TABLE)].

dump_advertisements() ->
    ensure_table(?ADV_TABLE, [set, public, named_table]),
    [{P, H} || {_, #adv{procedure = P, handler = H}} <- ets:tab2list(?ADV_TABLE)].

%% @doc Wipe all in-process subscriptions + advertisements. Use between
%% tests to avoid state leakage.
clear() ->
    case ets:info(?SUB_TABLE) of
        undefined -> ok;
        _ -> ets:delete_all_objects(?SUB_TABLE)
    end,
    case ets:info(?ADV_TABLE) of
        undefined -> ok;
        _ ->
            [safe_unadvertise_stream(P)
             || {P, _} <- ets:tab2list(?ADV_TABLE)],
            ets:delete_all_objects(?ADV_TABLE)
    end,
    ok.

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    process_flag(trap_exit, true),
    ensure_table(?SUB_TABLE, [bag, public, named_table]),
    ensure_table(?ADV_TABLE, [set, public, named_table]),
    %% Make sure macula is up — call_stream/register_stream_adv rely
    %% on macula_stream_local. Best-effort: don't fail init if the
    %% app isn't present (edge cases in isolated eunit runs).
    _ = application:ensure_all_started(macula),
    {ok, #{}}.

%% The facade (`hecate_mesh`) delegates everything to
%% `hecate_mesh_client:foo()` which uses `gen_server:call(?MODULE,
%% Msg)` for stateful operations. Map those gen_server messages onto
%% our direct-API helpers so the facade works against either backend.
handle_call(activate, _From, State)         -> {reply, ok, State};
handle_call(is_activated, _From, State)     -> {reply, true, State};
handle_call(get_client, _From, State)       -> {reply, {ok, self()}, State};
handle_call(get_status, _From, State)       -> {reply, get_status(), State};
handle_call({publish, Topic, Payload}, _From, State) ->
    {reply, publish(Topic, Payload), State};
handle_call({subscribe, Topic, Cb}, _From, State) ->
    {reply, subscribe(Topic, Cb), State};
handle_call({unsubscribe, Ref}, _From, State) ->
    {reply, unsubscribe(Ref), State};
handle_call({discover_subscribers, Topic}, _From, State) ->
    {reply, discover_subscribers(Topic), State};
handle_call({advertise, Procedure, Handler}, _From, State) ->
    {reply, advertise(Procedure, Handler), State};
handle_call({call, Procedure, Args, Timeout}, _From, State) ->
    {reply, call(Procedure, Args, Timeout), State};
handle_call({call, Procedure, Args, Opts, Timeout}, _From, State) ->
    {reply, call(Procedure, Args, Opts, Timeout), State};
handle_call({call_stream, Procedure, Args, Timeout}, _From, State) ->
    {reply, call_stream(Procedure, Args, #{}, Timeout), State};
handle_call({call_stream, Procedure, Args, Opts, Timeout}, _From, State) ->
    {reply, call_stream(Procedure, Args, Opts, Timeout), State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({register_sub, Topic, Cb}, State) ->
    _ = register_subscription(Topic, Cb), {noreply, State};
handle_cast({register_adv, Procedure, Handler}, State) ->
    _ = register_advertisement(Procedure, Handler), {noreply, State};
handle_cast({register_stream_adv, Procedure, Mode, Handler}, State) ->
    _ = register_stream_advertisement(Procedure, Mode, Handler), {noreply, State};
handle_cast({unregister_adv, Procedure}, State) ->
    _ = unregister_advertisement(Procedure), {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    %% The tables are named + owned by us. They die with the process;
    %% nothing to do explicitly.
    ok.

%%====================================================================
%% Internal
%%====================================================================

ensure_table(Name, Opts) ->
    case ets:info(Name) of
        undefined -> ets:new(Name, Opts);
        _         -> ok
    end.

ets_size(Name) ->
    case ets:info(Name, size) of
        undefined -> 0;
        N         -> N
    end.

%% @private Spawn a fire-and-forget process for each callback so one
%% slow subscriber doesn't head-of-line others.
invoke_cb(Cb, Msg) ->
    try Cb(Msg)
    catch
        Class:Reason:Stack ->
            logger:warning("[mesh_inproc] subscriber crashed ~p:~p~n~p",
                           [Class, Reason, Stack])
    end.

safe_invoke_handler(Handler, Args) when is_function(Handler, 1) ->
    try Handler(Args) of
        {ok, _} = Ok  -> Ok;
        {error, _} = E -> E;
        Other          -> {ok, Other}
    catch
        Class:Reason:Stack ->
            logger:warning("[mesh_inproc] handler crashed ~p:~p~n~p",
                           [Class, Reason, Stack]),
            {error, {handler_crashed, {Class, Reason}}}
    end;
safe_invoke_handler(_Handler, _Args) ->
    {error, bad_handler}.

ensure_macula_started() ->
    case application:ensure_all_started(macula) of
        {ok, _}    -> ok;
        {error, _} = E -> E
    end.

safe_unadvertise_stream(Procedure) ->
    try macula:unadvertise_stream(Procedure) of
        _ -> ok
    catch
        _:_ -> ok
    end.
