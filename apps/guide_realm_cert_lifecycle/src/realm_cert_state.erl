%%% @doc State module for the realm_cert aggregate.
%%%
%%% Singleton per daemon. The state captures the currently-held cert
%%% metadata (tier, handle, mri, expires_at, paths) reconstructed by
%%% replaying the event stream. The bootstrap worker reads this state
%%% on init to decide whether to acquire a fresh cert.
%%% @end
-module(realm_cert_state).
-behaviour(evoq_state).

-export([new/1, apply_event/2, to_map/1]).
-export([is_valid_now/1, current_cert/1]).

-record(state, {
    tier         :: binary() | undefined,
    handle       :: binary() | undefined,
    mri          :: binary() | undefined,
    expires_at   :: integer() | undefined,  %% ms epoch
    cert_path    :: binary() | undefined,
    key_path     :: binary() | undefined,
    ca_path      :: binary() | undefined
}).

-type state() :: #state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(_AggregateId) ->
    #state{}.

-spec apply_event(state(), map()) -> state().
apply_event(S,
            #{event_type := <<"provisional_cert_acquired_v1">>,
              tier := Tier, handle := Handle, mri := Mri,
              expires_at := ExpiresAt,
              cert_path := CertPath, key_path := KeyPath, ca_path := CaPath}) ->
    S#state{tier = Tier, handle = Handle, mri = Mri,
            expires_at = ExpiresAt,
            cert_path = CertPath, key_path = KeyPath, ca_path = CaPath};
apply_event(S, _) ->
    S.

-spec is_valid_now(state()) -> boolean().
is_valid_now(#state{expires_at = undefined}) -> false;
is_valid_now(#state{expires_at = ExpiresAt}) when is_integer(ExpiresAt) ->
    erlang:system_time(millisecond) < ExpiresAt.

-spec current_cert(state()) -> map() | undefined.
current_cert(#state{tier = undefined}) -> undefined;
current_cert(#state{tier = T, handle = H, mri = M, expires_at = E,
                    cert_path = CP, key_path = KP, ca_path = AP}) ->
    #{tier => T, handle => H, mri => M, expires_at => E,
      cert_path => CP, key_path => KP, ca_path => AP}.

-spec to_map(state()) -> map().
to_map(S) ->
    case current_cert(S) of
        undefined -> #{};
        Map -> Map
    end.
