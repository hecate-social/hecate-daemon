%%% @doc Application module for guide_site_lifecycle.
%%%
%%% On first boot, auto-initiates the site using a deterministic ID
%%% derived from the Erlang cookie (same cookie = same site).
%%% Also auto-admits this node into the site.
%%%
%%% On restarts, the aggregate rejects with already_initiated (harmless).
-module(guide_site_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).
-export([site_id/0]).

%% Suppress dialyzer warnings for dispatch calls
-dialyzer({nowarn_function, [auto_initiate_site/0, auto_admit_self/1]}).

start(_StartType, _StartArgs) ->
    {ok, Pid} = guide_site_lifecycle_sup:start_link(),
    auto_initiate_site(),
    {ok, Pid}.

stop(_State) ->
    ok.

%% @doc Derive deterministic site ID from Erlang cookie.
%% Same cookie = same site_id across all nodes.
-spec site_id() -> binary().
site_id() ->
    Cookie = erlang:get_cookie(),
    Hash = crypto:hash(sha256, atom_to_binary(Cookie)),
    binary:encode_hex(binary:part(Hash, 0, 8)).

%% @doc Auto-initiate site on daemon startup.
%% Waits for site_store to be ready, then dispatches initiate_site_v1.
%% On restarts, the aggregate rejects with already_initiated — harmless.
auto_initiate_site() ->
    spawn(fun() ->
        wait_for_store(site_store, 30),
        SiteId = site_id(),
        NodeName = atom_to_binary(node()),
        Now = erlang:system_time(millisecond),
        Cmd = initiate_site_v1:new(SiteId, NodeName, Now),
        case maybe_initiate_site:dispatch(Cmd) of
            {ok, _Version, _Events} ->
                logger:info("[site] Site initiated: ~s (by ~s)", [SiteId, NodeName]);
            {error, already_initiated} ->
                logger:debug("[site] Site already initiated: ~s", [SiteId]);
            {error, Reason} ->
                logger:warning("[site] Failed to auto-initiate site: ~p", [Reason])
        end,
        auto_admit_self(SiteId),
        announce_to_mesh()
    end).

%% @doc Auto-admit this node into the site.
auto_admit_self(SiteId) ->
    NodeName = atom_to_binary(node()),
    Now = erlang:system_time(millisecond),
    Cmd = admit_node_v1:new(NodeName, Now),
    case maybe_admit_node:dispatch_with_retry(SiteId, Cmd) of
        {ok, _Version, _Events} ->
            logger:info("[site] Node admitted: ~s", [NodeName]);
        {error, node_already_admitted} ->
            logger:debug("[site] Node already admitted: ~s", [NodeName]);
        {error, Reason} ->
            logger:warning("[site] Failed to auto-admit node: ~p", [Reason])
    end.

%% @doc Announce this node to the mesh (with delay for mesh to connect).
%% Starts periodic re-announcement so late-joining nodes discover us.
announce_to_mesh() ->
    timer:sleep(10_000),
    announce_site_node:announce(),
    announce_site_node:start_periodic().

%% @doc Wait for a ReckonDB store to be ready (store manager process registered).
wait_for_store(StoreId, MaxRetries) ->
    MgrName = reckon_db_naming:store_mgr_name(StoreId),
    wait_for_store(MgrName, MaxRetries, 0).

wait_for_store(MgrName, MaxRetries, Attempt) when Attempt >= MaxRetries ->
    logger:warning("[site] Store ~p not ready after ~b attempts, proceeding anyway", [MgrName, MaxRetries]);
wait_for_store(MgrName, MaxRetries, Attempt) ->
    case whereis(MgrName) of
        undefined ->
            timer:sleep(500),
            wait_for_store(MgrName, MaxRetries, Attempt + 1);
        _Pid ->
            ok
    end.
