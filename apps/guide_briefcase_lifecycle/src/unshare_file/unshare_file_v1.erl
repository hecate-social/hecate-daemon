%%% @doc unshare_file_v1 command.
%%%
%%% Flips a local briefcase file from `shared` back to `private`.
%%% Phase A: just updates local state. Phase B adds retraction of the
%%% mesh FACT. Phase D revokes outstanding licenses.
%%% @end
-module(unshare_file_v1).
-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_unshared_at/1]).

-record(unshare_file_v1, {
    file_id     :: binary(),
    unshared_at :: integer()
}).

-opaque unshare_file_v1() :: #unshare_file_v1{}.
-export_type([unshare_file_v1/0]).

command_type() -> unshare_file_v1.

-spec new(map()) -> {ok, unshare_file_v1()} | {error, missing_fields}.
new(#{file_id := FileId, unshared_at := UnsharedAt}) ->
    {ok, new(FileId, UnsharedAt)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), integer()) -> unshare_file_v1().
new(FileId, UnsharedAt) ->
    #unshare_file_v1{file_id = FileId, unshared_at = UnsharedAt}.

-spec to_map(unshare_file_v1()) -> map().
to_map(#unshare_file_v1{file_id = FileId, unshared_at = UnsharedAt}) ->
    #{file_id => FileId, unshared_at => UnsharedAt}.

-spec from_map(map()) -> {ok, unshare_file_v1()} | {error, term()}.
from_map(#{file_id := FileId, unshared_at := UnsharedAt}) ->
    {ok, #unshare_file_v1{file_id = FileId, unshared_at = UnsharedAt}};
from_map(_) ->
    {error, invalid_unshare_file_command}.

get_file_id(#unshare_file_v1{file_id = V}) -> V.
get_unshared_at(#unshare_file_v1{unshared_at = V}) -> V.
