%%% @doc share_mesh_artifact_v1 command.
%%%
%%% Agent-initiated: "store these bytes on the content-sharing fabric
%%% and tell me their MCID." The handler does the put_content call;
%%% the event records the resulting MCID + content_type + size.
%%% @end
-module(share_mesh_artifact_v1).
-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).

-record(share_mesh_artifact_v1, {
    bytes        :: binary(),
    content_type :: binary(),
    requested_at :: integer()
}).

-opaque share_mesh_artifact_v1() :: #share_mesh_artifact_v1{}.
-export_type([share_mesh_artifact_v1/0]).

command_type() -> share_mesh_artifact_v1.

-spec new(map()) -> {ok, share_mesh_artifact_v1()} | {error, term()}.
new(#{bytes := B, content_type := CT, requested_at := RA})
  when is_binary(B), is_binary(CT), is_integer(RA) ->
    {ok, #share_mesh_artifact_v1{bytes = B, content_type = CT, requested_at = RA}};
new(#{bytes := B, content_type := CT}) when is_binary(B), is_binary(CT) ->
    {ok, new(B, CT, erlang:system_time(millisecond))};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary(), integer()) -> share_mesh_artifact_v1().
new(Bytes, ContentType, RequestedAt)
  when is_binary(Bytes), is_binary(ContentType), is_integer(RequestedAt) ->
    #share_mesh_artifact_v1{bytes = Bytes, content_type = ContentType,
                            requested_at = RequestedAt}.

-spec to_map(share_mesh_artifact_v1()) -> map().
to_map(#share_mesh_artifact_v1{bytes = B, content_type = CT, requested_at = RA}) ->
    #{bytes => B, content_type => CT, requested_at => RA}.

-spec from_map(map()) -> {ok, share_mesh_artifact_v1()} | {error, term()}.
from_map(#{bytes := B, content_type := CT, requested_at := RA})
  when is_binary(B), is_binary(CT), is_integer(RA) ->
    {ok, #share_mesh_artifact_v1{bytes = B, content_type = CT, requested_at = RA}};
from_map(_) ->
    {error, invalid_share_mesh_artifact_command}.
