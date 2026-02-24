%%% @doc remove_api_key_v1 command
-module(remove_api_key_v1).

-export([new/2, to_map/1, from_map/1]).

-record(remove_api_key_v1, {
    provider   :: binary(),
    removed_at :: integer()
}).

-opaque remove_api_key_v1() :: #remove_api_key_v1{}.
-export_type([remove_api_key_v1/0]).

-spec new(binary(), integer()) -> remove_api_key_v1().
new(Provider, RemovedAt) ->
    #remove_api_key_v1{provider = Provider, removed_at = RemovedAt}.

-spec to_map(remove_api_key_v1()) -> map().
to_map(#remove_api_key_v1{provider = Provider, removed_at = RemovedAt}) ->
    #{provider => Provider, removed_at => RemovedAt}.

-spec from_map(map()) -> {ok, remove_api_key_v1()} | {error, term()}.
from_map(#{provider := Provider, removed_at := RemovedAt}) ->
    {ok, #remove_api_key_v1{provider = Provider, removed_at = RemovedAt}};
from_map(_) ->
    {error, invalid_remove_api_key_command}.
