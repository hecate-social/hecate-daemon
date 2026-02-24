%%% @doc api_key_configured_v1 event
-module(api_key_configured_v1).

-export([new/4, to_map/1, from_map/1]).

-record(api_key_configured_v1, {
    provider      :: binary(),
    api_key       :: binary(),
    label         :: binary(),
    configured_at :: integer()
}).

-opaque api_key_configured_v1() :: #api_key_configured_v1{}.
-export_type([api_key_configured_v1/0]).

-spec new(binary(), binary(), binary(), integer()) -> api_key_configured_v1().
new(Provider, ApiKey, Label, ConfiguredAt) ->
    #api_key_configured_v1{
        provider = Provider,
        api_key = ApiKey,
        label = Label,
        configured_at = ConfiguredAt
    }.

-spec to_map(api_key_configured_v1()) -> map().
to_map(#api_key_configured_v1{
    provider = Provider,
    api_key = ApiKey,
    label = Label,
    configured_at = ConfiguredAt
}) ->
    #{
        event_type => <<"api_key_configured_v1">>,
        provider => Provider,
        api_key => ApiKey,
        label => Label,
        configured_at => ConfiguredAt
    }.

-spec from_map(map()) -> {ok, api_key_configured_v1()} | {error, term()}.
from_map(#{provider := Provider, api_key := ApiKey, configured_at := ConfiguredAt} = Map) ->
    Label = maps:get(label, Map, Provider),
    {ok, #api_key_configured_v1{
        provider = Provider,
        api_key = ApiKey,
        label = Label,
        configured_at = ConfiguredAt
    }};
from_map(_) ->
    {error, invalid_api_key_configured_event}.
