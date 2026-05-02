%% @doc Parse a single `MACULA_RELAYS' entry into a structured
%% relay target.
%%
%% Tier 3 of the sovereign-overlay rollout. The env var grew an
%% additional shape:
%%
%% <ul>
%%   <li>`https://relay-fi-helsinki.macula.io:4433' — the existing
%%       hostname/URL form. Webpki-validated, public-IP path.</li>
%%   <li>`pubkey:&lt;Hex(Pubkey)&gt;[:&lt;Port&gt;]' — sovereign
%%       overlay form. The 32-byte Ed25519 pubkey IS the identity
%%       (encoded as 64 hex chars, lower or upper case); the dial
%%       layer derives the Yggdrasil IPv6 and pins the leaf cert
%%       by SPKI. Default port 4433. No DNS, no CA chain.</li>
%% </ul>
%%
%% Plan §4.4 originally proposed Base32. Switched to hex because
%% OTP ships `binary:decode_hex/1' but no native base32, and the
%% extra ~12 chars of hex over base32 is irrelevant for env-var
%% lengths. Document the switch in PLAN_SOVEREIGN_OVERLAY_PHASE1
%% when convenient.
-module(hecate_mesh_relay_target).

-export([parse/1, parse_list/1]).

-export_type([target/0]).

-type target() ::
        {url, binary()}
      | {pubkey, Pubkey :: binary(), Port :: inet:port_number()}.

-define(DEFAULT_PORT, 4433).

%% @doc Parse one entry. Whitespace is tolerated.
-spec parse(binary() | string()) -> {ok, target()} | {error, term()}.
parse(Entry) when is_binary(Entry) ->
    parse_step(string:trim(Entry));
parse(Entry) when is_list(Entry) ->
    parse(unicode:characters_to_binary(Entry)).

%% @doc Parse a full list (comma-separated string or list of entries).
%% Empty entries are silently dropped. A malformed entry aborts
%% the parse with `{error, {invalid_entry, Entry, Reason}}'.
-spec parse_list(binary() | string() | [binary() | string()]) ->
    {ok, [target()]} | {error, term()}.
parse_list(Bin) when is_binary(Bin) ->
    Parts = string:split(Bin, <<",">>, all),
    parse_list_step([P || P <- Parts, string:trim(P) =/= <<>>], []);
parse_list(Str) when is_list(Str), is_integer(hd(Str)) ->
    parse_list(unicode:characters_to_binary(Str));
parse_list(Lst) when is_list(Lst) ->
    parse_list_step(Lst, []).

parse_list_step([], Acc) ->
    {ok, lists:reverse(Acc)};
parse_list_step([Entry | Rest], Acc) ->
    case parse(Entry) of
        {ok, T}        -> parse_list_step(Rest, [T | Acc]);
        {error, R}     -> {error, {invalid_entry, Entry, R}}
    end.

%%==================================================================
%% Internals
%%==================================================================

parse_step(<<>>) ->
    {error, empty};
parse_step(<<"pubkey:", Rest/binary>>) ->
    parse_pubkey(Rest);
parse_step(<<"quic://pubkey:", Rest/binary>>) ->
    parse_pubkey(Rest);
parse_step(<<"https://pubkey:", Rest/binary>>) ->
    %% Tolerated for symmetry with the URL form even though the
    %% scheme is meaningless on the pubkey path.
    parse_pubkey(Rest);
parse_step(Url) ->
    {ok, {url, Url}}.

parse_pubkey(Rest) ->
    {HexBin, Port} = split_port(Rest),
    try binary:decode_hex(string:uppercase(HexBin)) of
        Bin when byte_size(Bin) =:= 32 ->
            {ok, {pubkey, Bin, Port}};
        Bin ->
            {error, {pubkey_size, byte_size(Bin)}}
    catch
        error:badarg -> {error, {bad_hex, HexBin}}
    end.

%% Format: `<Hex>' or `<Hex>:<Port>'. Hex chars never collide with
%% the colon separator.
split_port(Bin) ->
    case binary:split(Bin, <<":">>) of
        [Hex]            -> {Hex, ?DEFAULT_PORT};
        [Hex, PortBin]   -> {Hex, binary_to_integer(string:trim(PortBin))}
    end.
