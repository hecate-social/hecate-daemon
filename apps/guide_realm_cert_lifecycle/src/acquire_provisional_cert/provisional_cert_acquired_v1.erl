%%% @doc provisional_cert_acquired_v1 domain event.
%%%
%%% Internal domain event: the daemon successfully fetched a
%%% provisional cert from the realm and wrote it to disk. The event
%%% records metadata (tier, handle, mri, expires_at) and the file
%%% paths; the PEMs themselves stay on disk so secrets never enter
%%% the event store.
%%% @end
-module(provisional_cert_acquired_v1).
-behaviour(evoq_event).

-export([new/1, new/7, to_map/1, from_map/1]).
-export([event_type/0]).

-record(provisional_cert_acquired_v1, {
    tier       :: binary(),
    handle     :: binary(),
    mri        :: binary(),
    expires_at :: integer(),     %% ms epoch
    cert_path  :: binary(),
    key_path   :: binary(),
    ca_path    :: binary()
}).

-opaque provisional_cert_acquired_v1() :: #provisional_cert_acquired_v1{}.
-export_type([provisional_cert_acquired_v1/0]).

event_type() -> <<"provisional_cert_acquired_v1">>.

new(#{tier := T, handle := H, mri := M, expires_at := E,
      cert_path := CP, key_path := KP, ca_path := AP}) ->
    new(T, H, M, E, CP, KP, AP).

-spec new(binary(), binary(), binary(), integer(),
          binary(), binary(), binary()) -> provisional_cert_acquired_v1().
new(Tier, Handle, Mri, ExpiresAt, CertPath, KeyPath, CaPath)
  when is_binary(Tier), is_binary(Handle), is_binary(Mri),
       is_integer(ExpiresAt), is_binary(CertPath),
       is_binary(KeyPath), is_binary(CaPath) ->
    #provisional_cert_acquired_v1{tier = Tier, handle = Handle, mri = Mri,
                                  expires_at = ExpiresAt,
                                  cert_path = CertPath, key_path = KeyPath,
                                  ca_path = CaPath}.

-spec to_map(provisional_cert_acquired_v1()) -> map().
to_map(#provisional_cert_acquired_v1{tier = T, handle = H, mri = M,
                                     expires_at = E, cert_path = CP,
                                     key_path = KP, ca_path = AP}) ->
    #{event_type => <<"provisional_cert_acquired_v1">>,
      tier       => T,
      handle     => H,
      mri        => M,
      expires_at => E,
      cert_path  => CP,
      key_path   => KP,
      ca_path    => AP}.

-spec from_map(map()) -> {ok, provisional_cert_acquired_v1()} | {error, term()}.
from_map(#{tier := T, handle := H, mri := M, expires_at := E,
           cert_path := CP, key_path := KP, ca_path := AP})
  when is_binary(T), is_binary(H), is_binary(M), is_integer(E),
       is_binary(CP), is_binary(KP), is_binary(AP) ->
    {ok, #provisional_cert_acquired_v1{tier = T, handle = H, mri = M,
                                       expires_at = E, cert_path = CP,
                                       key_path = KP, ca_path = AP}};
from_map(_) ->
    {error, invalid_provisional_cert_acquired_event}.
