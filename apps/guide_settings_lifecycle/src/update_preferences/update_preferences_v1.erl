%%% @doc update_preferences_v1 command
-module(update_preferences_v1).

-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(update_preferences_v1, {
    preferences :: map(),
    updated_at  :: integer()
}).

-opaque update_preferences_v1() :: #update_preferences_v1{}.
-export_type([update_preferences_v1/0]).

-spec new(map(), integer()) -> update_preferences_v1().
command_type() -> update_preferences_v1.

new(#{preferences := Preferences, updated_at := UpdatedAt}) ->
    {ok, new(Preferences, UpdatedAt)};
new(_) ->
    {error, missing_fields}.

new(Preferences, UpdatedAt) ->
    #update_preferences_v1{preferences = Preferences, updated_at = UpdatedAt}.

-spec to_map(update_preferences_v1()) -> map().
to_map(#update_preferences_v1{preferences = Preferences, updated_at = UpdatedAt}) ->
    #{preferences => Preferences, updated_at => UpdatedAt}.

-spec from_map(map()) -> {ok, update_preferences_v1()} | {error, term()}.
from_map(#{preferences := Preferences, updated_at := UpdatedAt}) when is_map(Preferences) ->
    {ok, #update_preferences_v1{preferences = Preferences, updated_at = UpdatedAt}};
from_map(_) ->
    {error, invalid_update_preferences_command}.
