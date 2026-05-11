%%% @doc describe_mri desk: composite query.
%%% PLAN_RESOLVE_MESH_NAMES_PART1 §4.1.
%%%
%%% Rolls up — in a single call — everything the slice knows about
%%% an MRI: its verified record(s), the endorsement chain, the
%%% backlinks (who points at it), a consensus signal, and a
%%% last-modified timestamp.
%%%
%%% Phase 1.7 reality:
%%%   - `records'      — from resolve_mri:resolve/3. Fully working
%%%                      for station + proc MRIs; `{error, ...}'
%%%                      surfaces as `records => [], partial => true'
%%%                      for the rest.
%%%   - `endorsements' — empty for now. verify_trust_chain caches
%%%                      the endorsed member's pubkey in L3 but not
%%%                      the full RME record, so we can't replay it
%%%                      here without a fresh fetch + a way to
%%%                      derive the RME storage key (needs the
%%%                      realm pubkey, available, plus the member
%%%                      pubkey from the resolved record). A
%%%                      follow-up wires this; for now `[]' +
%%%                      `partial => true'.
%%%   - `backlinks'    — from backlinks:backlinks/2, which is
%%%                      itself a typed not-yet error → `[]' +
%%%                      `partial => true'.
%%%   - `consensus'    — `#{replicas => 1, agreed => 1}'. lookup_via_dht
%%%                      returns the first valid record, not a
%%%                      k-of-n quorum; "1 replica, 1 agreed" is
%%%                      literally what we observed. Multi-replica
%%%                      consensus is a substrate feature.
%%%   - `last_modified'— max `version'/`observed_at' across the
%%%                      records we did get; 0 when none.
%%%   - `partial'      — true when any component above couldn't be
%%%                      filled (so callers know the picture is
%%%                      incomplete, not authoritative).
%%%
%%% The gen_server holds no state; it's a registered worker. The
%%% public API is static.
%%% @end
-module(describe_mri).
-behaviour(gen_server).

-export([start_link/0, describe/2, describe/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @equiv describe(Pool, Mri, #{})
-spec describe(Pool :: pid(), Mri :: binary()) ->
    {ok, map()} | {error, atom() | tuple()}.
describe(Pool, Mri) ->
    describe(Pool, Mri, #{}).

%% @doc Composite description for an MRI. Opts are forwarded to
%% resolve_mri (find_fn for tests, etc.).
-spec describe(Pool :: pid(), Mri :: binary(), Opts :: map()) ->
    {ok, map()} | {error, atom() | tuple()}.
describe(Pool, Mri, Opts) ->
    {Records, RecPartial} =
        case resolve_mri:resolve(Pool, Mri, Opts) of
            {ok, Rs} when is_list(Rs) -> {Rs, false};
            {error, _}                -> {[], true}
        end,
    %% Endorsements + backlinks are follow-ups (see module doc).
    {Endorsements, EndPartial} = {[], true},
    {Backlinks, BlPartial} =
        case backlinks:backlinks(Pool, Mri) of
            {ok, Bs} when is_list(Bs) -> {Bs, false};
            {error, _}                -> {[], true}
        end,
    Description = #{
        mri           => Mri,
        records       => Records,
        endorsements  => Endorsements,
        backlinks     => Backlinks,
        consensus     => #{replicas => 1, agreed => 1},
        last_modified => last_modified(Records),
        partial       => RecPartial orelse EndPartial orelse BlPartial
    },
    {ok, Description}.

%% Latest observed_at across the verified records (each carries
%% observed_at :: epoch ms). 0 when there are none.
last_modified([]) -> 0;
last_modified(Records) ->
    lists:max([maps:get(observed_at, R, 0) || R <- Records]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{}}.
handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.
