%%% @doc Process Manager: on BEAM cluster nodeup, admit node to site.
%%%
%%% Listens for Erlang distribution nodeup events (Layer 2).
%%% When a new BEAM node joins the cluster, auto-admits it to the site.
%%% No mesh/QUIC needed — this is a LAN operation.
%%% @end
-module(on_site_node_announced_admit_node).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ok = net_kernel:monitor_nodes(true),
    logger:info("[site-pm] Monitoring BEAM cluster for new nodes"),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({nodeup, Node}, State) ->
    logger:info("[site-pm] Node joined cluster: ~p", [Node]),
    spawn(fun() -> maybe_admit(Node) end),
    {noreply, State};

handle_info({nodedown, Node}, State) ->
    logger:info("[site-pm] Node left cluster: ~p", [Node]),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    net_kernel:monitor_nodes(false),
    ok.

%%% ===================================================================
%%% Internal
%%% ===================================================================

maybe_admit(Node) ->
    NodeName = atom_to_binary(Node),
    SiteId = guide_site_lifecycle_app:site_id(),
    admit_with_retry(SiteId, NodeName, 3).

admit_with_retry(_SiteId, NodeName, 0) ->
    logger:warning("[site-pm] Giving up admitting ~s after retries", [NodeName]);
admit_with_retry(SiteId, NodeName, Retries) ->
    Cmd = admit_node_v1:new(NodeName, erlang:system_time(millisecond)),
    case maybe_admit_node:dispatch(SiteId, Cmd) of
        {ok, _V, _Events} ->
            logger:info("[site-pm] Admitted node: ~s", [NodeName]);
        {error, node_already_admitted} ->
            ok;
        {error, {wrong_expected_version, _}} ->
            timer:sleep(500),
            admit_with_retry(SiteId, NodeName, Retries - 1);
        {error, Reason} ->
            logger:warning("[site-pm] Failed to admit ~s: ~p", [NodeName, Reason])
    end.
