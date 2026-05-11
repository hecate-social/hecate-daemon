%%% @doc Reverse-IPv6 PTR resolver. PLAN PART1 §3.4.9.
%%%
%%% Qnames under `*.ip6.arpa.' carry an IPv6 address in nibble-form
%%% (one hex digit per label, reversed). Resolution is fundamentally
%%% different from forward MRIs: we decode the qname to an IPv6
%%% address, check whether it falls inside any realm's allocated
%%% prefix (from the realm_directory), then look up the
%%% address_pubkey_map record to find which station owns the
%%% address. The synthesised PTR target points to that station's
%%% `_st' qname.
%%%
%%% This module owns step 1 only (qname → IPv6 address — pure).
%%% Steps 2-4 happen in the lookup pipeline upstream because they
%%% require DHT lookup + trust chain walk; not pure label algebra.
%%%
%%% Phase 0 status: pure decode is implementable now but the
%%% pipeline that consumes it does not yet exist. Returns
%%% `{error, reverse_v6_lookup_required}' so callers know to route
%%% to the lookup desk once it lands.
%%% @end
-module(qname_reverse_v6).

-export([resolve/1, decode_qname/1]).

%% @doc Resolve a reverse-arpa qname. Currently signals that the
%% downstream lookup pipeline is needed (the address_pubkey_map
%% lookup + trust chain walk happen upstream, not here).
-spec resolve(QName :: binary()) -> {ok, binary()} | {error, atom()}.
resolve(_QName) ->
    {error, reverse_v6_lookup_required}.

%% @doc Pure decode: take a `*.ip6.arpa.' qname and return its IPv6
%% address as a `{N1, N2, ..., N8}' tuple (8x 16-bit groups).
%% Returns `{error, malformed_reverse_arpa}' if the nibble-form is
%% wrong shape.
%%
%% Example: `c.b.a.0.0.0.0.0.0.0.0.0.0.0.0.0.f.f.0.c.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa'
%% → `{ok, {16#fc00, 16#0, 16#0, 16#0, 16#0, 16#0, 16#0, 16#abc}}'.
-spec decode_qname(QName :: binary()) ->
    {ok, {0..16#FFFF, 0..16#FFFF, 0..16#FFFF, 0..16#FFFF,
          0..16#FFFF, 0..16#FFFF, 0..16#FFFF, 0..16#FFFF}}
    | {error, atom()}.
decode_qname(QName) when is_binary(QName) ->
    Trimmed = strip_trailing_dot(QName),
    case lists:reverse(binary:split(Trimmed, <<".">>, [global])) of
        [<<"arpa">>, <<"ip6">> | NibbleLabels] when length(NibbleLabels) =:= 32 ->
            decode_nibbles(NibbleLabels);
        _ ->
            {error, malformed_reverse_arpa}
    end.

%% Strip a single trailing dot if present.
strip_trailing_dot(<<>>) -> <<>>;
strip_trailing_dot(B) ->
    case binary:last(B) of
        $. -> binary:part(B, 0, byte_size(B) - 1);
        _  -> B
    end.

%% Decode 32 single-hex-digit labels (in network order after the
%% lists:reverse above) into 8 16-bit groups.
decode_nibbles(Labels) ->
    case decode_nibbles(Labels, []) of
        {error, _} = E -> E;
        Nibbles when length(Nibbles) =:= 32 ->
            Groups = group_nibbles(Nibbles),
            {ok, list_to_tuple(Groups)}
    end.

decode_nibbles([], Acc) ->
    lists:reverse(Acc);
decode_nibbles([<<C>> | Rest], Acc) when (C >= $0 andalso C =< $9);
                                          (C >= $a andalso C =< $f) ->
    Nibble = nibble_value(C),
    decode_nibbles(Rest, [Nibble | Acc]);
decode_nibbles(_, _) ->
    {error, malformed_reverse_arpa}.

nibble_value(C) when C >= $0, C =< $9 -> C - $0;
nibble_value(C) when C >= $a, C =< $f -> C - $a + 10.

%% Group 32 nibbles into 8 16-bit values (4 nibbles each).
group_nibbles(Nibbles) ->
    group_nibbles(Nibbles, []).

group_nibbles([], Acc) ->
    lists:reverse(Acc);
group_nibbles([N1, N2, N3, N4 | Rest], Acc) ->
    Group = (N1 bsl 12) bor (N2 bsl 8) bor (N3 bsl 4) bor N4,
    group_nibbles(Rest, [Group | Acc]).
