%%% @doc verify_host_delegation: optional link 5 of the trust chain.
%%%
%%% Only invoked when the verified leaf is a `hosted_address_map'
%%% — those leaves carry a delegation map proving the host is
%%% authorised to speak for the daemon's identity in the realm.
%%%
%%% Delegates the actual signature math to
%%% `macula_record:verify_host_delegation/1' (which already
%%% exists in the SDK; see `macula-io/macula/src/record/macula_record.erl').
%%% Adds the policy checks PART1 §5.2 specifies on top:
%%%   - delegation `realm_pubkey' must equal the trust chain's
%%%     `realm_root_pubkey'
%%%   - `not_before <= now <= not_after'
%%% @end
-module(verify_host_delegation).

-export([verify/4]).

-spec verify(HostDelegation :: map(),
             DaemonPubkey :: binary(),
             RealmRootPubkey :: binary(),
             Opts :: map()) ->
    ok | {error, atom()}.
verify(HostDelegation, DaemonPubkey, RealmRootPubkey, Opts) ->
    NowMs = maps:get(now_ms, Opts, erlang:system_time(millisecond)),
    case check_daemon_pubkey(HostDelegation, DaemonPubkey) of
        ok ->
            case macula_record:verify_host_delegation(HostDelegation) of
                {ok, _} ->
                    case check_realm_match(HostDelegation, RealmRootPubkey) of
                        ok            -> check_validity_window(HostDelegation, NowMs);
                        {error, _} = E -> E
                    end;
                {error, _} ->
                    {error, delegation_invalid}
            end;
        {error, _} = E ->
            E
    end.

check_daemon_pubkey(#{daemon_pubkey := Pk}, DaemonPubkey) when Pk =:= DaemonPubkey ->
    ok;
check_daemon_pubkey(_, _) ->
    {error, delegation_invalid}.

check_realm_match(#{realm_pubkey := R}, RealmRootPubkey) when R =:= RealmRootPubkey ->
    ok;
check_realm_match(_, _) ->
    {error, delegation_invalid}.

check_validity_window(#{not_before := NB, not_after := NA}, NowMs)
  when is_integer(NB), is_integer(NA), NowMs >= NB, NowMs =< NA ->
    ok;
check_validity_window(#{not_before := NB}, NowMs)
  when is_integer(NB), NowMs < NB ->
    {error, clock_skew};
check_validity_window(#{not_after := NA}, NowMs)
  when is_integer(NA), NowMs > NA ->
    {error, delegation_invalid};
check_validity_window(_, _) ->
    {error, delegation_invalid}.
