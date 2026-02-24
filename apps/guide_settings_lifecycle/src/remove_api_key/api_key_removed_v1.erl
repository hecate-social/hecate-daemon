%%% @doc api_key_removed_v1 event
-module(api_key_removed_v1).

-export([new/2, to_map/1, from_map/1]).

-record(api_key_removed_v1, {
    provider   :: binary(),
    removed_at :: integer()
}).

-opaque api_key_removed_v1() :: #api_key_removed_v1{}.
-export_type([api_key_removed_v1/0]).

-spec new(binary(), integer()) -> api_key_removed_v1().
new(Provider, RemovedAt) ->
    #api_key_removed_v1{provider = Provider, removed_at = RemovedAt}.

-spec to_map(api_key_removed_v1()) -> map().
to_map(#api_key_removed_v1{provider = Provider, removed_at = RemovedAt}) ->
    #{
        event_type => <<"api_key_removed_v1">>,
        provider => Provider,
        removed_at => RemovedAt
    }.

-spec from_map(map()) -> {ok, api_key_removed_v1()} | {error, term()}.
from_map(#{provider := Provider, removed_at := RemovedAt}) ->
    {ok, #api_key_removed_v1{provider = Provider, removed_at = RemovedAt}};
from_map(_) ->
    {error, invalid_api_key_removed_event}.
