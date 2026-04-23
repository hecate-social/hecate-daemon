%%% @doc Process Manager: realm_membership_confirmed_v1 →
%%% listen_for_membership_revoked:subscribe(member_did).
%%%
%%% Wires the post-join gate: the membership-revoked listener stays
%%% dormant until this PM fires (live or via evoq replay on boot)
%%% and casts the confirmed member DID. The listener then subscribes
%%% to the realm-tier mesh fact with that DID as own_mri, so a
%%% subsequent revoke fact actually matches.
%%%
%%% Replay semantics: evoq replays historical
%%% `realm_membership_confirmed_v1` events to fresh handlers, which
%%% restores the subscription on daemon restart without any boot
%%% poll of the read model.
%%% @end
-module(on_realm_membership_confirmed_subscribe_to_revoked).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"realm_membership_confirmed_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case gf(member_did, Data) of
        undefined ->
            logger:warning("[pm.subscribe_to_revoked] missing member_did "
                           "on confirmed event");
        Did when is_binary(Did) ->
            listen_for_membership_revoked:subscribe(Did),
            logger:info("[pm.subscribe_to_revoked] requested subscribe "
                        "member_did=~s", [Did])
    end,
    {ok, State}.

%%====================================================================
%% Internal
%%====================================================================

gf(Key, Data) when is_map(Data) ->
    maps:get(Key, Data, maps:get(atom_to_binary(Key, utf8), Data, undefined));
gf(_Key, _Data) ->
    undefined.
