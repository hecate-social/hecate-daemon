%%% @doc Process Manager: realm_membership_confirmed_v1 → fetch K_realm.
%%%
%%% Thin event-handler that delegates to `realm_key_fetcher` so the
%%% confirm-driven path and the boot-time catch-up share exactly one
%%% implementation.
%%% @end
-module(on_realm_membership_confirmed_fetch_key).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"realm_membership_confirmed_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    MembershipId = gf(membership_id, Data),
    Realm = resolve_realm(Data),
    log_result(MembershipId, Realm, realm_key_fetcher:fetch_and_store(MembershipId, Realm)),
    {ok, State}.

%%====================================================================
%% Internal
%%====================================================================

%% realm_id on a confirmed event is the URI string by convention.
%% Falls back to realm_url host when realm_id is missing.
resolve_realm(Data) ->
    case gf(realm_id, Data) of
        undefined -> gf(realm_url, Data);
        Realm     -> Realm
    end.

log_result(_MId, Realm, {ok, Version}) ->
    logger:info("[pm.fetch_key] K_realm v~p stored for ~s", [Version, Realm]);
log_result(_MId, Realm, {error, Reason}) ->
    logger:warning("[pm.fetch_key] skipped for ~p: ~p", [Realm, Reason]).

gf(Key, Data) when is_map(Data) ->
    maps:get(Key, Data, maps:get(atom_to_binary(Key, utf8), Data, undefined));
gf(_Key, _Data) ->
    undefined.
