%%%-------------------------------------------------------------------
%%% @doc Hecate mesh client — multi-homed relay connections.
%%%
%%% Wraps macula_multi_relay for node multi-homing. Maintains N
%%% concurrent QUIC connections to diverse relays. Subscribes on ALL,
%%% publishes via PRIMARY, deduplicates incoming by message_id.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, get_client/0, get_status/0, publish/2, subscribe/2,
         unsubscribe/1, discover_subscribers/1, advertise/2, call/3, call/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    client :: pid() | undefined,
    realm :: binary(),
    identity :: binary(),
    relays :: [binary()],
    connections :: pos_integer()
}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

get_client() ->
    gen_server:call(?MODULE, get_client).

publish(Topic, Payload) ->
    gen_server:call(?MODULE, {publish, Topic, Payload}).

subscribe(Topic, Callback) ->
    gen_server:call(?MODULE, {subscribe, Topic, Callback}).

unsubscribe(SubRef) ->
    gen_server:call(?MODULE, {unsubscribe, SubRef}).

advertise(Procedure, Handler) ->
    gen_server:call(?MODULE, {advertise, Procedure, Handler}).

call(Procedure, Args, Timeout) ->
    gen_server:call(?MODULE, {rpc_call, Procedure, Args, Timeout}, Timeout + 1000).

call(Procedure, Args, _Opts, Timeout) ->
    call(Procedure, Args, Timeout).

get_status() ->
    gen_server:call(?MODULE, get_status).

discover_subscribers(_Topic) ->
    {ok, []}.

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Identity = application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>),
    Bootstrap = case os:getenv("MACULA_RELAYS") of
        false -> application:get_env(hecate, bootstrap,
                     [<<"https://relay00.macula.io:4433">>]);
        EnvStr -> [list_to_binary(string:trim(U))
                   || U <- string:split(EnvStr, ",", all),
                      string:trim(U) =/= ""]
    end,
    Relays = [ensure_binary(R) || R <- Bootstrap],

    %% Build site metadata from cookie + env vars
    Cookie = atom_to_binary(erlang:get_cookie()),
    SiteId = binary:part(binary:encode_hex(crypto:hash(sha256, Cookie)), 0, 16),
    Site = maps:from_list([{K, V} || {K, V} <- [
        {site_id, SiteId},
        {name, env_bin("HECATE_SITE_NAME", SiteId)},
        {city, env_bin("HECATE_GEO_CITY", undefined)},
        {country, env_bin("HECATE_GEO_COUNTRY", undefined)},
        {lat, env_float("HECATE_GEO_LAT")},
        {lng, env_float("HECATE_GEO_LNG")},
        {site_type, env_bin("HECATE_SITE_TYPE", <<"daemon">>)}
    ], V =/= undefined]),

    Connections = case os:getenv("MACULA_CONNECTIONS") of
        false -> application:get_env(hecate, mesh_connections, 2);
        ConnStr ->
            try list_to_integer(string:trim(ConnStr))
            catch error:badarg -> 2
            end
    end,

    logger:info("[hecate_mesh] Starting multi-relay client (realm: ~s, site: ~s, "
                "connections: ~b, relays: ~p)",
                [Realm, SiteId, Connections, Relays]),

    {ok, Client} = macula_multi_relay:start_link(#{
        relays => Relays,
        realm => Realm,
        identity => Identity,
        site => Site,
        connections => Connections
    }),

    logger:info("[hecate_mesh] Multi-relay client started (~b connections)", [Connections]),

    {ok, #state{
        client = Client,
        realm = Realm,
        identity = Identity,
        relays = Relays,
        connections = Connections
    }}.

handle_call(get_client, _From, #state{client = Client} = State) ->
    {reply, {ok, Client}, State};

handle_call(get_status, _From, #state{client = Client, realm = Realm,
                                       identity = Identity, relays = Relays,
                                       connections = Connections} = State) ->
    MultiStatus = get_multi_status(Client),
    Status = #{
        connected => is_pid(Client),
        realm => Realm,
        identity => Identity,
        relays => Relays,
        connections => Connections,
        multi_relay => MultiStatus,
        mode => multi_relay
    },
    {reply, {ok, Status}, State};

handle_call({publish, Topic, Payload}, _From, #state{client = Client} = State) ->
    macula_multi_relay:publish(Client, Topic, Payload),
    {reply, ok, State};

handle_call({subscribe, Topic, Callback}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:subscribe(Client, Topic, Callback) end),
    {reply, Result, State};

handle_call({unsubscribe, SubRef}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:unsubscribe(Client, SubRef) end),
    {reply, Result, State};

handle_call({advertise, Procedure, Handler}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:advertise(Client, Procedure, Handler) end),
    {reply, Result, State};

handle_call({rpc_call, Procedure, Args, Timeout}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:call(Client, Procedure, Args, Timeout) end),
    {reply, Result, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{client = Client}) ->
    catch macula_multi_relay:stop(Client),
    ok.

%%====================================================================
%% Internal
%%====================================================================

%% Catch timeouts from multi_relay when mesh isn't connected yet.
%% Without this, callers crash during boot if relay DNS fails or
%% connection takes longer than gen_server:call timeout.
safe_mesh_call(Fun) ->
    try Fun()
    catch
        exit:{timeout, _} -> {error, mesh_timeout};
        exit:{noproc, _} -> {error, mesh_not_started};
        exit:{{timeout, _}, _} -> {error, mesh_timeout}
    end.

get_multi_status(Client) when is_pid(Client) ->
    case macula_multi_relay:get_status(Client) of
        {ok, MS} -> MS;
        _ -> #{}
    end;
get_multi_status(_) -> #{}.

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(S) when is_list(S) -> list_to_binary(S).

env_bin(Key, Default) ->
    case os:getenv(Key) of
        false -> Default;
        "" -> Default;
        Val -> list_to_binary(Val)
    end.

env_float(Key) ->
    case os:getenv(Key) of
        false -> undefined;
        "" -> undefined;
        Val -> parse_float_safe(Val)
    end.

parse_float_safe(Val) ->
    case string:to_float(Val) of
        {F, []} -> F;
        _ ->
            case string:to_integer(Val) of
                {I, []} -> float(I);
                _ -> undefined
            end
    end.
