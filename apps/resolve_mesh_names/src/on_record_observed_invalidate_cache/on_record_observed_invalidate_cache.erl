%%% @doc Process Manager: on `record_observed_v1' from the local
%%% DHT, invalidate cached entries for the affected key(s) and
%%% cascade through dependent layers (PLAN PART1 §6.2).
%%%
%%% Subscribes via macula:subscribe_records on relevant record
%%% types at boot. The mesh substrate guarantees push-delivery
%%% within ~1 s (verified macula 4.2.9 + macula-station 57f4c8d).
%%%
%%% Lives in this slice (target domain: cache_records). Reacts to
%%% events emitted by macula_dht infrastructure (source domain).
%%%
%%% Phase 0: stub gen_server. Phase 1 wires the subscription +
%%% routing to cache_invalidate.
%%% @end
-module(on_record_observed_invalidate_cache).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Phase 1: macula:subscribe_records(Pool, [<<"tombstone">>,
    %% <<"realm_directory">>, <<"foundation_realm_trust_list">>,
    %% <<"realm_member_endorsement">>], self()) — and per-MRI leaf
    %% subscriptions added when MRIs are first cached.
    {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
