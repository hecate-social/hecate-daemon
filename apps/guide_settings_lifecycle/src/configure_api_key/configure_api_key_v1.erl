%%% @doc configure_api_key_v1 command
-module(configure_api_key_v1).

-export([new/4, to_map/1, from_map/1]).

-record(configure_api_key_v1, {
    provider      :: binary(),
    api_key       :: binary(),
    label         :: binary(),
    configured_at :: integer()
}).

-opaque configure_api_key_v1() :: #configure_api_key_v1{}.
-export_type([configure_api_key_v1/0]).

-spec new(binary(), binary(), binary(), integer()) -> configure_api_key_v1().
new(Provider, ApiKey, Label, ConfiguredAt) ->
    #configure_api_key_v1{
        provider = Provider,
        api_key = ApiKey,
        label = Label,
        configured_at = ConfiguredAt
    }.

-spec to_map(configure_api_key_v1()) -> map().
to_map(#configure_api_key_v1{
    provider = Provider,
    api_key = ApiKey,
    label = Label,
    configured_at = ConfiguredAt
}) ->
    #{
        provider => Provider,
        api_key => ApiKey,
        label => Label,
        configured_at => ConfiguredAt
    }.

-spec from_map(map()) -> {ok, configure_api_key_v1()} | {error, term()}.
from_map(#{provider := Provider, api_key := ApiKey, configured_at := ConfiguredAt} = Map) ->
    Label = maps:get(label, Map, Provider),
    {ok, #configure_api_key_v1{
        provider = Provider,
        api_key = ApiKey,
        label = Label,
        configured_at = ConfiguredAt
    }};
from_map(_) ->
    {error, invalid_configure_api_key_command}.
