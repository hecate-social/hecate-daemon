%%% @doc Per-type rule for MRI type `station'. Special case (PLAN
%%% PART1 §3.4.13): the qname is a single z-base-32 label = the
%%% station's Ed25519 pubkey. The MRI form is `mri:station:<pubkey>'
%%% — no realm field, no path.
%%%
%%% Example: `<<"abc...xyz">>._st.macula.io.' → `mri:station:<32-byte-pubkey>'.
%%%
%%% Phase 0 status: gated on macula 4.3.0 (`macula_z32' module +
%%% `station' MRI type). Until 4.3.0 ships, both `resolve/2' and
%%% `format_pubkey/1' return `{error, macula_z32_unavailable}'.
%%% This is the honest stub — never silently succeeds with garbage.
%%% @end
-module(qname_station).

-export([resolve/2, format_pubkey/1]).

%% @doc Decode a qname's z32 label into a station MRI.
%%   Left  expected: `[<<Z32Label>>]'
%%   Right expected: `[<<"macula">>, <<"io">>]' (the synthetic suffix)
-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve([_Z32Label], _RightSuffix) ->
    %% Phase 1 (post macula 4.3.0):
    %%   case macula_z32:decode(Z32Label) of
    %%       {ok, Pubkey}   -> {ok, <<"mri:station:", Pubkey/binary>>};
    %%       {error, _} = E -> E
    %%   end.
    {error, macula_z32_unavailable};
resolve(_, _) ->
    {error, malformed_qname}.

%% @doc Encode a station pubkey into its z32 label form for the
%% reverse direction (used by qname_to_mri:format/1 when synthesising
%% PTR targets and SOA MNAMEs).
%%
%% Phase 1 (post macula 4.3.0):
%%   format_pubkey(Pubkey) -> {ok, macula_z32:encode(Pubkey)}.
-spec format_pubkey(Pubkey :: binary()) ->
    {ok, binary()} | {error, atom()}.
format_pubkey(_Pubkey) ->
    {error, macula_z32_unavailable}.
