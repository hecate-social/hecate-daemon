%%% @doc Process Manager: relay realm-membership events to peers via pg.
%%%
%%% Subscribes to local realm_memberships_store events and re-publishes
%%% them through the boot_daemon pg seam so peer nodes (typically
%%% headless beams clustered to an attended host) can inherit the
%%% realm membership.
%%%
%%% Events relayed:
%%%   * realm_membership_initiated_v1
%%%   * realm_membership_confirmed_v1
%%%   * realm_credentials_secured_v1    (encrypted_credentials is
%%%                                      binary-opaque to this PM —
%%%                                      the receiver decrypts locally
%%%                                      with the shared Erlang cookie)
%%%
%%% Idempotency on the inbound side prevents infinite broadcast loops:
%%% when a receiver dispatches the inherited command its aggregate is
%%% already in the resulting state, so the dispatch yields
%%% {error, already_*} and no new event fires → no PM trigger → no
%%% secondary broadcast.
%%% @end
-module(relay_realm_events_to_peers).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"realm_membership_initiated_v1">>,
     <<"realm_membership_confirmed_v1">>,
     <<"realm_credentials_secured_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(EventType, Event, _Metadata, State) ->
    Payload = maps:get(data, Event, Event),
    Peers = peer_count(),
    case Peers of
        0 ->
            logger:debug("[relay_realm] no peers — skipping relay of ~s", [EventType]),
            ok;
        _ ->
            logger:info("[relay_realm] relaying ~s to ~b peer(s)", [EventType, Peers]),
            boot_daemon:broadcast_inherited(EventType, Payload)
    end,
    {ok, State}.

peer_count() ->
    try length(pg:get_members(boot_daemon:inherited_pg_group())) - 1
    catch _:_ -> 0
    end.
