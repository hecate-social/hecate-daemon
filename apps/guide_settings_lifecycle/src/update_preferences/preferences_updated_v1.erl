%%% @doc preferences_updated_v1 event
-module(preferences_updated_v1).

-export([new/2, to_map/1, from_map/1]).

-record(preferences_updated_v1, {
    preferences :: map(),
    updated_at  :: integer()
}).

-opaque preferences_updated_v1() :: #preferences_updated_v1{}.
-export_type([preferences_updated_v1/0]).

-spec new(map(), integer()) -> preferences_updated_v1().
new(Preferences, UpdatedAt) ->
    #preferences_updated_v1{preferences = Preferences, updated_at = UpdatedAt}.

-spec to_map(preferences_updated_v1()) -> map().
to_map(#preferences_updated_v1{preferences = Preferences, updated_at = UpdatedAt}) ->
    #{
        event_type => <<"preferences_updated_v1">>,
        preferences => Preferences,
        updated_at => UpdatedAt
    }.

-spec from_map(map()) -> {ok, preferences_updated_v1()} | {error, term()}.
from_map(#{preferences := Preferences, updated_at := UpdatedAt}) when is_map(Preferences) ->
    {ok, #preferences_updated_v1{preferences = Preferences, updated_at = UpdatedAt}};
from_map(_) ->
    {error, invalid_preferences_updated_event}.
