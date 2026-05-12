%%% @doc Process manager: relay realm-membership events to the site.
%%%
%%% A "site" is the cluster of co-located daemons (the Erlang dist
%%% cluster; `boot_daemon:site_daemons_group/0' is the pg group every
%%% daemon's `listen_for_inherited_realm_memberships' joins). When an
%%% attended daemon (the one that did the browser OAuth join) writes a
%%% realm-membership event to its local realm_memberships_store, this
%%% PM re-publishes it to the other daemons in the site so a headless
%%% daemon can pick up the (shared, cookie-encrypted) refresh token
%%% and provision its OWN per-daemon cert via the realm's
%%% /api/v1/cluster/provision endpoint.
%%%
%%% Events relayed:
%%%   * realm_membership_initiated_v1   (informational on the receiver)
%%%   * realm_membership_confirmed_v1   (informational on the receiver)
%%%   * realm_credentials_secured_v1    (encrypted_credentials is
%%%                                      binary-opaque to this PM —
%%%                                      the receiver decrypts it with
%%%                                      the shared Erlang cookie and
%%%                                      uses only the refresh token)
%%%
%%% No broadcast storm: the receiver does NOT re-dispatch the attended
%%% daemon's commands (it mints its own membership), so this PM never
%%% re-fires on a relayed event.
%%% @end
-module(relay_realm_events_to_site).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"realm_membership_initiated_v1">>,
     <<"realm_membership_confirmed_v1">>,
     <<"realm_credentials_secured_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(EventType, Event, _Metadata, State) ->
    Payload = maps:get(data, Event, Event),
    case site_daemon_count() of
        0 ->
            logger:debug("[relay_realm] no other site daemons — skipping relay of ~s", [EventType]),
            ok;
        N ->
            logger:info("[relay_realm] relaying ~s to ~b site daemon(s)", [EventType, N]),
            boot_daemon:broadcast_to_site(EventType, Payload)
    end,
    {ok, State}.

%% Other daemons in this site (pg group members minus self).
site_daemon_count() ->
    try length(pg:get_members(boot_daemon:site_daemons_group())) - 1
    catch _:_ -> 0
    end.
