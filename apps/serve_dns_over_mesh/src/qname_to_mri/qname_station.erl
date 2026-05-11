%%% @doc Per-type rule for MRI type `station'. Special case (PLAN
%%% PART1 §3.4.13): the qname is a single z-base-32 label = the
%%% station's Ed25519 pubkey. The MRI form is `mri:station:<z32-pubkey>'
%%% — no realm field semantics beyond the pubkey, no path.
%%%
%%% Example: `<z32-of-pubkey>._st.macula.io.' ↔ `mri:station:<z32-of-pubkey>'.
%%%
%%% Implementation requires macula 4.3.0 (macula_z32 codec +
%%% station type registration in macula_mri).
%%% @end
-module(qname_station).

-export([resolve/2, format_pubkey/1]).

%% @doc Build a station MRI from a z32-encoded leaf label.
%%   Left  expected: `[<<Z32Label>>]' (single 52-char z32 label
%%                   for a 32-byte Ed25519 pubkey)
%%   Right expected: `[]' (parent chain — empty for stations,
%%                   which are self-rooted; the dispatcher passes
%%                   `[]' here after stripping the mesh suffix)
%%
%% Returns `{ok, <<"mri:station:", Z32/binary>>}' on a valid z32
%% label that decodes to 32 bytes; surfaces the macula_z32 /
%% macula_mri error otherwise.
-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom() | tuple()}.
resolve([Z32Label], []) ->
    %% Validate via macula_mri:new/3 — that does the z32 decode +
    %% length check + station-specific path validation in one go,
    %% returning {ok, Mri} | {error, _}. Surface the typed error
    %% directly to the caller.
    macula_mri:new(station, Z32Label, []);
resolve(_, _) ->
    {error, malformed_qname}.

%% @doc Encode a 32-byte pubkey as its z32 label form for the
%% reverse direction (used by qname_to_mri:format/1 when
%% synthesising PTR targets and SOA MNAMEs that point to a station).
-spec format_pubkey(Pubkey :: binary()) ->
    {ok, binary()} | {error, atom()}.
format_pubkey(<<_:32/binary>> = Pubkey) ->
    {ok, macula_z32:encode(Pubkey)};
format_pubkey(Pubkey) when is_binary(Pubkey) ->
    %% Caller passed an already-z32-encoded pubkey (or we got the
    %% pubkey via a path that stored it as z32 in the first place).
    %% Validate by round-tripping; if it decodes to 32 bytes,
    %% pass through as-is.
    case macula_z32:decode(Pubkey) of
        {ok, <<_:32/binary>>} -> {ok, Pubkey};
        {ok, _Other}          -> {error, invalid_station_pubkey_length};
        {error, invalid_z32}  -> {error, invalid_station_pubkey_encoding}
    end;
format_pubkey(_) ->
    {error, invalid_station_pubkey}.
