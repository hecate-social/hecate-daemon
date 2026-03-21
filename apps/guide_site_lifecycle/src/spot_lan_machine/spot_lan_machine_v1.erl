%%% @doc spot_lan_machine_v1 command
-module(spot_lan_machine_v1).

-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).

-record(spot_lan_machine_v1, {
    mac       :: binary(),
    ip        :: binary(),
    hostname  :: binary(),
    interface :: binary(),
    ssh       :: boolean(),
    hecate    :: map()
}).

-opaque spot_lan_machine_v1() :: #spot_lan_machine_v1{}.
-export_type([spot_lan_machine_v1/0]).

command_type() -> spot_lan_machine.

new(#{mac := MAC, ip := IP} = Opts) ->
    #spot_lan_machine_v1{
        mac = MAC,
        ip = IP,
        hostname = maps:get(hostname, Opts, IP),
        interface = maps:get(interface, Opts, <<>>),
        ssh = maps:get(ssh, Opts, false),
        hecate = maps:get(hecate, Opts, #{running => false})
    }.

-spec to_map(spot_lan_machine_v1()) -> map().
to_map(#spot_lan_machine_v1{} = C) ->
    #{
        mac => C#spot_lan_machine_v1.mac,
        ip => C#spot_lan_machine_v1.ip,
        hostname => C#spot_lan_machine_v1.hostname,
        interface => C#spot_lan_machine_v1.interface,
        ssh => C#spot_lan_machine_v1.ssh,
        hecate => C#spot_lan_machine_v1.hecate
    }.

-spec from_map(map()) -> {ok, spot_lan_machine_v1()} | {error, term()}.
from_map(#{mac := _, ip := _} = M) ->
    {ok, new(M)};
from_map(_) ->
    {error, invalid_spot_command}.
