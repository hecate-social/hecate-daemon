%%% @doc watch_mri desk: subscription registry. Owns the ETS table
%%% mapping `sub_handle() → {pid(), monitor_ref(), mri()}', and
%%% the inverse `mri() → [sub_handle()]'.
%%%
%%% Phase 0: stub. Phase 1 wires:
%%%   - macula:subscribe_records on (record_type, mri) on first
%%%     subscriber for an MRI
%%%   - per-pid monitor; auto-unwatch on subscriber-DOWN
%%%   - dispatcher routes push events to the right mailbox(es)
%%% @end
-module(watch_mri).
-behaviour(gen_server).

-export([start_link/0, watch/3, unwatch/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SUBS_TABLE, resolve_mesh_names_watch_subs).

%% @doc Subscribe to changes for an MRI.
-spec watch(term(), binary(), pid()) -> {ok, reference()} | {error, atom()}.
watch(_Pool, _Mri, _Pid) -> {error, watch_not_yet_implemented}.

%% @doc Cancel a subscription. Idempotent.
-spec unwatch(reference()) -> ok.
unwatch(_Handle) -> ok.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    catch ets:delete(?SUBS_TABLE),
    ?SUBS_TABLE = ets:new(?SUBS_TABLE, [named_table, public, set,
                                        {read_concurrency, true}]),
    {ok, #{phase => scaffold, table => ?SUBS_TABLE}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
