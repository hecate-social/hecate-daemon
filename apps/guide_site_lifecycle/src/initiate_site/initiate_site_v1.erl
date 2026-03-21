%%% @doc initiate_site_v1 command
-module(initiate_site_v1).

-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).

-record(initiate_site_v1, {
    site_id      :: binary(),
    initiated_by :: binary(),
    initiated_at :: integer()
}).

-opaque initiate_site_v1() :: #initiate_site_v1{}.
-export_type([initiate_site_v1/0]).

-spec new(binary(), binary(), integer()) -> initiate_site_v1().
command_type() -> initiate_site.

new(#{site_id := SiteId, initiated_by := InitiatedBy, initiated_at := InitiatedAt}) ->
    {ok, new(SiteId, InitiatedBy, InitiatedAt)};
new(_) ->
    {error, missing_fields}.

new(SiteId, InitiatedBy, InitiatedAt) ->
    #initiate_site_v1{
        site_id = SiteId,
        initiated_by = InitiatedBy,
        initiated_at = InitiatedAt
    }.

-spec to_map(initiate_site_v1()) -> map().
to_map(#initiate_site_v1{
    site_id = SiteId,
    initiated_by = InitiatedBy,
    initiated_at = InitiatedAt
}) ->
    #{
        site_id => SiteId,
        initiated_by => InitiatedBy,
        initiated_at => InitiatedAt
    }.

-spec from_map(map()) -> {ok, initiate_site_v1()} | {error, term()}.
from_map(#{site_id := SId, initiated_by := By, initiated_at := At}) ->
    {ok, #initiate_site_v1{
        site_id = SId,
        initiated_by = By,
        initiated_at = At
    }};
from_map(_) ->
    {error, invalid_initiate_site_command}.
