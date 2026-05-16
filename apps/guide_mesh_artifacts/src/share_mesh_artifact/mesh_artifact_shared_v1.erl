%%% @doc mesh_artifact_shared_v1 domain event.
%%%
%%% Records that an artifact has been pushed onto the content-sharing
%%% fabric. The MCID is the audit + retrieval anchor: with it any
%%% reachable peer can pull the bytes via `mesh:get_content/1'.
%%% @end
-module(mesh_artifact_shared_v1).
-behaviour(evoq_event).

-export([new/1, new/4, to_map/1, from_map/1]).
-export([event_type/0]).

-record(mesh_artifact_shared_v1, {
    mcid         :: binary(),
    content_type :: binary(),
    size_bytes   :: non_neg_integer(),
    shared_at    :: integer()
}).

-opaque mesh_artifact_shared_v1() :: #mesh_artifact_shared_v1{}.
-export_type([mesh_artifact_shared_v1/0]).

event_type() -> <<"mesh_artifact_shared_v1">>.

new(#{mcid := M, content_type := CT, size_bytes := S, shared_at := SA}) ->
    new(M, CT, S, SA).

-spec new(binary(), binary(), non_neg_integer(), integer()) -> mesh_artifact_shared_v1().
new(MCID, ContentType, SizeBytes, SharedAt)
  when is_binary(MCID), is_binary(ContentType),
       is_integer(SizeBytes), SizeBytes >= 0,
       is_integer(SharedAt) ->
    #mesh_artifact_shared_v1{mcid = MCID,
                             content_type = ContentType,
                             size_bytes = SizeBytes,
                             shared_at = SharedAt}.

-spec to_map(mesh_artifact_shared_v1()) -> map().
to_map(#mesh_artifact_shared_v1{mcid = M, content_type = CT, size_bytes = S, shared_at = SA}) ->
    #{
        event_type   => <<"mesh_artifact_shared_v1">>,
        mcid         => M,
        content_type => CT,
        size_bytes   => S,
        shared_at    => SA
    }.

-spec from_map(map()) -> {ok, mesh_artifact_shared_v1()} | {error, term()}.
from_map(#{mcid := M, content_type := CT, size_bytes := S, shared_at := SA})
  when is_binary(M), is_binary(CT), is_integer(S), is_integer(SA) ->
    {ok, #mesh_artifact_shared_v1{mcid = M, content_type = CT, size_bytes = S, shared_at = SA}};
from_map(_) ->
    {error, invalid_mesh_artifact_shared_event}.
