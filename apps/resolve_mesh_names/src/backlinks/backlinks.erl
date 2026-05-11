%%% @doc backlinks desk: reverse-direction queries — "who endorsed
%%% this name?", "who delegated to this station?".
%%% PLAN_RESOLVE_MESH_NAMES_PART1 §4.2.
%%%
%%% Status: not yet implemented. Honest `{error, backlinks_not_yet_implemented}'.
%%%
%%% Why deferred: the plan's two backlink sources don't exist in
%%% the macula 4.x SDK as the plan describes:
%%%   - `realm_directory.trust_delegates' listing — the SDK
%%%     realm_directory payload has only `admin_key', no delegate
%%%     list.
%%%   - `realm_member_endorsement' records "whose path matches" —
%%%     SDK RMEs have no `path' field; they're realm-wide, member-
%%%     keyed. To find "who endorsed Mri" you'd have to map Mri →
%%%     member-pubkey first (the same indirection that blocks
%%%     resolve_mri for non-station/proc types), then scan all
%%%     RMEs of type 0x05 across the mesh for `member_node ==
%%%     that-pubkey'. A full type scan over every station's DHT
%%%     shard is heavy and the design isn't pinned.
%%%
%%% Closing this needs either a reverse index (storage_key →
%%% who-points-at-it, maintained alongside the cache) or a
%%% realm-scoped backlink record (a macula 4.4.0 candidate).
%%% Until then this function returns the typed error rather than
%%% an empty list — `[]' would be a lie ("no backlinks exist"),
%%% the error is honest ("I can't tell you yet").
%%% @end
-module(backlinks).
-behaviour(gen_server).

-export([start_link/0, backlinks/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Reverse query: who points at this MRI. See module doc for
%% why this currently returns a typed not-implemented error.
-spec backlinks(Pool :: pid(), Mri :: binary()) ->
    {ok, [map()]} | {error, atom()}.
backlinks(_Pool, _Mri) ->
    {error, backlinks_not_yet_implemented}.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{}}.
handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.
