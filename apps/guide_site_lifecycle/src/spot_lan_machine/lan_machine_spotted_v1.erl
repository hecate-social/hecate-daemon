%%% @doc lan_machine_spotted_v1 event
-module(lan_machine_spotted_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(lan_machine_spotted_v1, {
    mac       :: binary(),
    observer  :: binary(),
    ip        :: binary(),
    hostname  :: binary(),
    interface :: binary(),
    ssh       :: boolean(),
    hecate    :: map(),
    spotted_at :: integer()
}).

-opaque lan_machine_spotted_v1() :: #lan_machine_spotted_v1{}.
-export_type([lan_machine_spotted_v1/0]).

event_type() -> <<"lan_machine_spotted_v1">>.

new(#{mac := MAC, observer := Observer, ip := IP, hostname := Hostname,
      interface := Iface, ssh := SSH, hecate := Hecate} = Opts) ->
    #lan_machine_spotted_v1{
        mac = MAC,
        observer = Observer,
        ip = IP,
        hostname = Hostname,
        interface = Iface,
        ssh = SSH,
        hecate = Hecate,
        spotted_at = maps:get(spotted_at, Opts, erlang:system_time(millisecond))
    }.

-spec to_map(lan_machine_spotted_v1()) -> map().
to_map(#lan_machine_spotted_v1{} = E) ->
    #{
        mac => E#lan_machine_spotted_v1.mac,
        observer => E#lan_machine_spotted_v1.observer,
        ip => E#lan_machine_spotted_v1.ip,
        hostname => E#lan_machine_spotted_v1.hostname,
        interface => E#lan_machine_spotted_v1.interface,
        ssh => E#lan_machine_spotted_v1.ssh,
        hecate => E#lan_machine_spotted_v1.hecate,
        spotted_at => E#lan_machine_spotted_v1.spotted_at
    }.

-spec from_map(map()) -> {ok, lan_machine_spotted_v1()} | {error, term()}.
from_map(#{mac := MAC, ip := IP} = M) ->
    {ok, #lan_machine_spotted_v1{
        mac = MAC,
        observer = maps:get(observer, M, <<"unknown">>),
        ip = IP,
        hostname = maps:get(hostname, M, IP),
        interface = maps:get(interface, M, <<>>),
        ssh = maps:get(ssh, M, false),
        hecate = maps:get(hecate, M, #{running => false}),
        spotted_at = maps:get(spotted_at, M, 0)
    }};
from_map(_) ->
    {error, invalid_lan_machine_spotted}.
