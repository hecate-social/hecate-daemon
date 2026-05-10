%%% @doc EDE (Extended DNS Errors, RFC 8914) info-code encoder.
%%% Maps internal failure-mode atoms to the wire-format
%%% `(info-code, extra-text)' tuple that lives in the EDNS0 OPT
%%% pseudo-RR.
%%%
%%% Phase 0: stub. See PLAN_DNS_OVER_MESH_PART1 §6 for the
%%% complete cause → (rcode, EDE code, extra-text) table.
%%% @end
-module(compose_ede).

-export([encode/2]).

-spec encode(Cause :: atom(), Detail :: binary() | undefined) ->
    binary().
encode(_Cause, _Detail) ->
    %% Phase 1 returns the wire-encoded OPT-OPTION with EDE
    %% info-code + UTF-8 extra-text. Empty binary keeps Phase 0
    %% callers from breaking.
    <<>>.
