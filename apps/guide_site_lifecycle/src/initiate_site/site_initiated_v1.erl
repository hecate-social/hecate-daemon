%%% @doc site_initiated_v1 event
-module(site_initiated_v1).

-behaviour(evoq_event).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([event_type/0]).

-record(site_initiated_v1, {
    site_id      :: binary(),
    initiated_by :: binary(),
    initiated_at :: integer()
}).

-opaque site_initiated_v1() :: #site_initiated_v1{}.
-export_type([site_initiated_v1/0]).

-spec new(binary(), binary(), integer()) -> site_initiated_v1().
event_type() -> <<"site_initiated_v1">>.

new(#{site_id := SiteId, initiated_by := InitiatedBy, initiated_at := InitiatedAt}) ->
    new(SiteId, InitiatedBy, InitiatedAt).

new(SiteId, InitiatedBy, InitiatedAt) ->
    #site_initiated_v1{
        site_id = SiteId,
        initiated_by = InitiatedBy,
        initiated_at = InitiatedAt
    }.

-spec to_map(site_initiated_v1()) -> map().
to_map(#site_initiated_v1{
    site_id = SiteId,
    initiated_by = InitiatedBy,
    initiated_at = InitiatedAt
}) ->
    #{
        event_type => <<"site_initiated_v1">>,
        site_id => SiteId,
        initiated_by => InitiatedBy,
        initiated_at => InitiatedAt
    }.

-spec from_map(map()) -> {ok, site_initiated_v1()} | {error, term()}.
from_map(#{site_id := SId, initiated_by := By, initiated_at := At}) ->
    {ok, #site_initiated_v1{
        site_id = SId,
        initiated_by = By,
        initiated_at = At
    }};
from_map(_) ->
    {error, invalid_site_initiated_event}.
