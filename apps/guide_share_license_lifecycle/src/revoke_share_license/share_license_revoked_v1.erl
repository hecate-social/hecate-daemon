%%% @doc share_license_revoked_v1 domain event.
%%%
%%% Issuer-local terminal event on the `issued-license-{id}` stream.
%%% Also picked up by the mesh emitter
%%% (`share_license_revoked_v1_to_mesh`) which publishes a FACT on
%%% `{realm}.licenses.revoked` for recipients to observe.
%%%
%%% Event type name uses `share_` prefix to avoid collision with
%%% appstore's `license_revoked_v1` in the VM-global
%%% `evoq_event_type_registry`.
%%% @end
-module(share_license_revoked_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(share_license_revoked_v1, {
    license_id :: binary(),
    grantee    :: binary() | undefined,
    realm      :: binary() | undefined,
    issuer_did :: binary() | undefined,
    reason     :: atom(),
    revoked_at :: integer()
}).

-opaque share_license_revoked_v1() :: #share_license_revoked_v1{}.
-export_type([share_license_revoked_v1/0]).

event_type() -> <<"share_license_revoked_v1">>.

-spec new(map()) -> {ok, share_license_revoked_v1()} | {error, term()}.
new(#{license_id := L} = P) ->
    {ok, #share_license_revoked_v1{
        license_id = L,
        grantee    = maps:get(grantee,    P, undefined),
        realm      = maps:get(realm,      P, undefined),
        issuer_did = maps:get(issuer_did, P, undefined),
        reason     = maps:get(reason,     P, revoked),
        revoked_at = maps:get(revoked_at, P, erlang:system_time(millisecond))}};
new(_) ->
    {error, missing_fields}.

-spec to_map(share_license_revoked_v1()) -> map().
to_map(#share_license_revoked_v1{} = E) ->
    #{event_type => event_type(),
      license_id => E#share_license_revoked_v1.license_id,
      grantee    => E#share_license_revoked_v1.grantee,
      realm      => E#share_license_revoked_v1.realm,
      issuer_did => E#share_license_revoked_v1.issuer_did,
      reason     => E#share_license_revoked_v1.reason,
      revoked_at => E#share_license_revoked_v1.revoked_at}.

-spec from_map(map()) -> {ok, share_license_revoked_v1()} | {error, term()}.
from_map(Map) -> new(Map).
