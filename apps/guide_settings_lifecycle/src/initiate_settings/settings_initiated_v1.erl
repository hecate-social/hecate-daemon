%%% @doc settings_initiated_v1 event
-module(settings_initiated_v1).

-export([new/3, to_map/1, from_map/1]).

-record(settings_initiated_v1, {
    linux_user   :: binary(),
    hostname     :: binary(),
    initiated_at :: integer()
}).

-opaque settings_initiated_v1() :: #settings_initiated_v1{}.
-export_type([settings_initiated_v1/0]).

-spec new(binary(), binary(), integer()) -> settings_initiated_v1().
new(LinuxUser, Hostname, InitiatedAt) ->
    #settings_initiated_v1{
        linux_user = LinuxUser,
        hostname = Hostname,
        initiated_at = InitiatedAt
    }.

-spec to_map(settings_initiated_v1()) -> map().
to_map(#settings_initiated_v1{
    linux_user = LinuxUser,
    hostname = Hostname,
    initiated_at = InitiatedAt
}) ->
    #{
        event_type => <<"settings_initiated_v1">>,
        linux_user => LinuxUser,
        hostname => Hostname,
        initiated_at => InitiatedAt
    }.

-spec from_map(map()) -> {ok, settings_initiated_v1()} | {error, term()}.
from_map(#{linux_user := LinuxUser, hostname := Hostname, initiated_at := InitiatedAt}) ->
    {ok, #settings_initiated_v1{
        linux_user = LinuxUser,
        hostname = Hostname,
        initiated_at = InitiatedAt
    }};
from_map(_) ->
    {error, invalid_settings_initiated_event}.
