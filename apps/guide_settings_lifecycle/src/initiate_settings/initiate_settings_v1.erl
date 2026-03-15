%%% @doc initiate_settings_v1 command
-module(initiate_settings_v1).

-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_linux_user/1, get_hostname/1, get_initiated_at/1]).

-record(initiate_settings_v1, {
    linux_user   :: binary(),
    hostname     :: binary(),
    initiated_at :: integer()
}).

-opaque initiate_settings_v1() :: #initiate_settings_v1{}.
-export_type([initiate_settings_v1/0]).

-spec new(binary(), binary(), integer()) -> initiate_settings_v1().
command_type() -> initiate_settings_v1.

new(#{linux_user := LinuxUser, hostname := Hostname, initiated_at := InitiatedAt}) ->
    {ok, new(LinuxUser, Hostname, InitiatedAt)};
new(_) ->
    {error, missing_fields}.

new(LinuxUser, Hostname, InitiatedAt) ->
    #initiate_settings_v1{
        linux_user = LinuxUser,
        hostname = Hostname,
        initiated_at = InitiatedAt
    }.

-spec to_map(initiate_settings_v1()) -> map().
to_map(#initiate_settings_v1{
    linux_user = LinuxUser,
    hostname = Hostname,
    initiated_at = InitiatedAt
}) ->
    #{
        linux_user => LinuxUser,
        hostname => Hostname,
        initiated_at => InitiatedAt
    }.

-spec from_map(map()) -> {ok, initiate_settings_v1()} | {error, term()}.
from_map(#{linux_user := LinuxUser, hostname := Hostname, initiated_at := InitiatedAt}) ->
    {ok, #initiate_settings_v1{
        linux_user = LinuxUser,
        hostname = Hostname,
        initiated_at = InitiatedAt
    }};
from_map(_) ->
    {error, invalid_initiate_settings_command}.

get_linux_user(#initiate_settings_v1{linux_user = V}) -> V.
get_hostname(#initiate_settings_v1{hostname = V}) -> V.
get_initiated_at(#initiate_settings_v1{initiated_at = V}) -> V.
