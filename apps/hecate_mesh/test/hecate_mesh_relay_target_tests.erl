-module(hecate_mesh_relay_target_tests).

-include_lib("eunit/include/eunit.hrl").

%% 32-byte pubkey from the live Helsinki ygg sidecar.
-define(HELSINKI_HEX,
    <<"949a5f007122c1babc4794f1169cef74dee51f1e0edefcb8ff2cc50cfe170566">>).
-define(HELSINKI_PUBKEY,
    <<16#94, 16#9a, 16#5f, 16#00, 16#71, 16#22, 16#c1, 16#ba,
      16#bc, 16#47, 16#94, 16#f1, 16#16, 16#9c, 16#ef, 16#74,
      16#de, 16#e5, 16#1f, 16#1e, 16#0e, 16#de, 16#fc, 16#b8,
      16#ff, 16#2c, 16#c5, 16#0c, 16#fe, 16#17, 16#05, 16#66>>).

%%==================================================================
%% URL form (existing path)
%%==================================================================

url_form_test() ->
    ?assertEqual(
       {ok, {url, <<"https://relay-fi-helsinki.macula.io:4433">>}},
       hecate_mesh_relay_target:parse(
         <<"https://relay-fi-helsinki.macula.io:4433">>)).

url_form_string_test() ->
    ?assertEqual(
       {ok, {url, <<"https://relay00.macula.io:4433">>}},
       hecate_mesh_relay_target:parse("https://relay00.macula.io:4433")).

url_form_trims_whitespace_test() ->
    ?assertEqual(
       {ok, {url, <<"https://x.io">>}},
       hecate_mesh_relay_target:parse(<<"  https://x.io  ">>)).

%%==================================================================
%% Pubkey form
%%==================================================================

pubkey_form_default_port_test() ->
    Entry = <<"pubkey:", ?HELSINKI_HEX/binary>>,
    ?assertEqual(
       {ok, {pubkey, ?HELSINKI_PUBKEY, 4433}},
       hecate_mesh_relay_target:parse(Entry)).

pubkey_form_custom_port_test() ->
    Entry = <<"pubkey:", ?HELSINKI_HEX/binary, ":9999">>,
    ?assertEqual(
       {ok, {pubkey, ?HELSINKI_PUBKEY, 9999}},
       hecate_mesh_relay_target:parse(Entry)).

pubkey_form_uppercase_hex_test() ->
    Upper = string:uppercase(?HELSINKI_HEX),
    Entry = <<"pubkey:", Upper/binary>>,
    ?assertEqual(
       {ok, {pubkey, ?HELSINKI_PUBKEY, 4433}},
       hecate_mesh_relay_target:parse(Entry)).

pubkey_form_quic_scheme_test() ->
    Entry = <<"quic://pubkey:", ?HELSINKI_HEX/binary, ":4433">>,
    ?assertEqual(
       {ok, {pubkey, ?HELSINKI_PUBKEY, 4433}},
       hecate_mesh_relay_target:parse(Entry)).

pubkey_form_https_scheme_test() ->
    Entry = <<"https://pubkey:", ?HELSINKI_HEX/binary>>,
    ?assertEqual(
       {ok, {pubkey, ?HELSINKI_PUBKEY, 4433}},
       hecate_mesh_relay_target:parse(Entry)).

%%==================================================================
%% Errors
%%==================================================================

empty_entry_test() ->
    ?assertEqual({error, empty}, hecate_mesh_relay_target:parse(<<>>)).

short_pubkey_test() ->
    %% 31 bytes = 62 hex chars
    Short = binary:copy(<<"ab">>, 31),
    Entry = <<"pubkey:", Short/binary>>,
    ?assertMatch({error, {pubkey_size, 31}},
                 hecate_mesh_relay_target:parse(Entry)).

bad_hex_test() ->
    Entry = <<"pubkey:notvalidhex">>,
    ?assertMatch({error, {bad_hex, _}},
                 hecate_mesh_relay_target:parse(Entry)).

%%==================================================================
%% parse_list/1
%%==================================================================

mixed_list_test() ->
    Mixed = <<"https://relay-fi-helsinki.macula.io:4433,pubkey:",
              ?HELSINKI_HEX/binary, ":4433">>,
    ?assertEqual(
       {ok, [{url, <<"https://relay-fi-helsinki.macula.io:4433">>},
             {pubkey, ?HELSINKI_PUBKEY, 4433}]},
       hecate_mesh_relay_target:parse_list(Mixed)).

empty_entries_silently_dropped_test() ->
    Mixed = <<",  ,https://x.io,,">>,
    ?assertEqual(
       {ok, [{url, <<"https://x.io">>}]},
       hecate_mesh_relay_target:parse_list(Mixed)).

malformed_entry_aborts_test() ->
    Bad = <<"https://x.io,pubkey:notvalidhex">>,
    ?assertMatch({error, {invalid_entry, _, {bad_hex, _}}},
                 hecate_mesh_relay_target:parse_list(Bad)).
