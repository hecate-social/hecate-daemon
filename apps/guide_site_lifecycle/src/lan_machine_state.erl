%%% @doc State module for LAN machine aggregate.
%%%
%%% Each LAN machine is identified by MAC address.
%%% Only meaningful state changes produce events:
%%% - First spot (new machine)
%%% - Hecate status changed (installed/removed)
%%% - Dismissed by user
%%% Re-spots with no changes are idempotent (no new event).
%%% @end
-module(lan_machine_state).

-behaviour(evoq_state).

-include("lan_machine_state.hrl").
-include("lan_machine_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #lan_machine_state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(_AggregateId) ->
    #lan_machine_state{
        mac = undefined,
        ip = undefined,
        hostname = undefined,
        interface = undefined,
        ssh = false,
        hecate = #{running => false},
        status = 0,
        first_seen = undefined,
        last_seen = undefined
    }.

-spec apply_event(state(), map()) -> state().
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

-spec to_map(state()) -> map().
to_map(#lan_machine_state{} = S) ->
    #{
        mac        => S#lan_machine_state.mac,
        ip         => S#lan_machine_state.ip,
        hostname   => S#lan_machine_state.hostname,
        interface  => S#lan_machine_state.interface,
        ssh        => S#lan_machine_state.ssh,
        hecate     => S#lan_machine_state.hecate,
        status     => S#lan_machine_state.status,
        first_seen => S#lan_machine_state.first_seen,
        last_seen  => S#lan_machine_state.last_seen
    }.

%% ===================================================================
%% Event application
%% ===================================================================

do_apply(<<"lan_machine_spotted_v1">>, State, Event) ->
    Now = gf(spotted_at, Event),
    FirstSeen = case State#lan_machine_state.first_seen of
        undefined -> Now;
        Existing -> Existing
    end,
    State#lan_machine_state{
        mac = gf(mac, Event),
        ip = gf(ip, Event),
        hostname = gf(hostname, Event),
        interface = gf(interface, Event),
        ssh = gf(ssh, Event),
        hecate = gf(hecate, Event),
        first_seen = FirstSeen,
        last_seen = Now,
        status = State#lan_machine_state.status bor ?LAN_MACHINE_SPOTTED
    };

do_apply(<<"lan_machine_dismissed_v1">>, State, _Event) ->
    State#lan_machine_state{
        status = State#lan_machine_state.status bor ?LAN_MACHINE_DISMISSED
    };

do_apply(_UnknownType, State, _Event) ->
    State.

%% ===================================================================
%% Internal
%% ===================================================================

gf(Key, Event) ->
    BinKey = atom_to_binary(Key),
    maps:get(BinKey, Event, maps:get(Key, Event, undefined)).
