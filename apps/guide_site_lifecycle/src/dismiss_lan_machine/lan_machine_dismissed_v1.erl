%%% @doc lan_machine_dismissed_v1 event
-module(lan_machine_dismissed_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(lan_machine_dismissed_v1, {
    mac          :: binary(),
    observer     :: binary(),
    dismissed_at :: integer()
}).

-opaque lan_machine_dismissed_v1() :: #lan_machine_dismissed_v1{}.
-export_type([lan_machine_dismissed_v1/0]).

event_type() -> <<"lan_machine_dismissed_v1">>.

new(#{mac := MAC, observer := Observer} = Opts) ->
    #lan_machine_dismissed_v1{
        mac = MAC,
        observer = Observer,
        dismissed_at = maps:get(dismissed_at, Opts, erlang:system_time(millisecond))
    }.

-spec to_map(lan_machine_dismissed_v1()) -> map().
to_map(#lan_machine_dismissed_v1{} = E) ->
    #{
        mac => E#lan_machine_dismissed_v1.mac,
        observer => E#lan_machine_dismissed_v1.observer,
        dismissed_at => E#lan_machine_dismissed_v1.dismissed_at
    }.

-spec from_map(map()) -> {ok, lan_machine_dismissed_v1()} | {error, term()}.
from_map(#{mac := MAC} = M) ->
    {ok, #lan_machine_dismissed_v1{
        mac = MAC,
        observer = maps:get(observer, M, <<"unknown">>),
        dismissed_at = maps:get(dismissed_at, M, 0)
    }};
from_map(_) ->
    {error, invalid_dismissed_event}.
