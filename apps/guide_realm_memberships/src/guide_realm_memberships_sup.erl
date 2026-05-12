%%% @doc Top-level supervisor for guide_realm_memberships.
%%%
%%% Hosts the process manager that fetches K_realm from the realm
%%% server on `realm_membership_confirmed_v1`.
-module(guide_realm_memberships_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{
            id => on_realm_membership_confirmed_fetch_key,
            start => {evoq_event_handler, start_link,
                      [on_realm_membership_confirmed_fetch_key, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        on_realm_membership_confirmed_fetch_key]
        },
        #{
            id => on_realm_shared_key_stored_announce_public_key,
            start => {evoq_event_handler, start_link,
                      [on_realm_shared_key_stored_announce_public_key, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        on_realm_shared_key_stored_announce_public_key]
        },
        #{
            id => identity_public_key_announced_v1_to_dht,
            start => {evoq_event_handler, start_link,
                      [identity_public_key_announced_v1_to_dht, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        identity_public_key_announced_v1_to_dht]
        },
        #{
            id => catch_up_realm_keys,
            start => {catch_up_realm_keys, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [catch_up_realm_keys]
        },
        %% Resignation DHT emitter (single-event, not batched).
        #{
            id => realm_membership_resigned_v1_to_dht,
            start => {evoq_event_handler, start_link,
                      [realm_membership_resigned_v1_to_dht, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        realm_membership_resigned_v1_to_dht]
        },
        %% Admin-revoke listener: subscribes only after a confirmed
        %% membership exists (gated by the two PMs below).
        #{
            id => listen_for_membership_revoked,
            start => {listen_for_membership_revoked, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [listen_for_membership_revoked]
        },
        %% Post-join gate: realm_membership_confirmed_v1 →
        %% listen_for_membership_revoked:subscribe(member_did).
        #{
            id => on_realm_membership_confirmed_subscribe_to_revoked,
            start => {evoq_event_handler, start_link,
                      [on_realm_membership_confirmed_subscribe_to_revoked, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        on_realm_membership_confirmed_subscribe_to_revoked]
        },
        %% Post-end gate: realm_membership_ended_v1 →
        %% listen_for_membership_revoked:unsubscribe().
        #{
            id => on_realm_membership_ended_unsubscribe_from_revoked,
            start => {evoq_event_handler, start_link,
                      [on_realm_membership_ended_unsubscribe_from_revoked, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        on_realm_membership_ended_unsubscribe_from_revoked]
        },
        %% Relay local realm events to the site (the co-located daemon
        %% cluster) via pg (outbound). Lets an attended daemon's OAuth
        %% flow propagate to headless daemons in the same site, which
        %% then mint their own per-daemon cert via cluster-provision.
        #{
            id => relay_realm_events_to_site,
            start => {evoq_event_handler, start_link,
                      [relay_realm_events_to_site, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        relay_realm_events_to_site]
        },
        %% Inbound listener for relayed realm events (the cluster-
        %% inherited-join seam). Joins the boot_daemon site pg group
        %% and, on relayed credentials, provisions this daemon's own
        %% per-daemon cert via the realm's /api/v1/cluster/provision.
        #{
            id => listen_for_inherited_realm_memberships,
            start => {listen_for_inherited_realm_memberships, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [listen_for_inherited_realm_memberships]
        }
    ],
    {ok, {SupFlags, Children}}.
