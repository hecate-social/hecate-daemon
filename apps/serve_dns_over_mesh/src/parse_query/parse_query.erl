%%% @doc RFC 1035 wire decoder for DNS query messages.
%%%
%%% Phase 0: stub. Phase 1 implements: header decode (12 bytes —
%%% id, flags, qd/an/ns/ar counts), question section (compressed
%%% name + qtype + qclass), EDNS0 OPT pseudo-RR detection (delegates
%%% to `parse_query_edns0') for advertised UDP buffer size + EDE
%%% support.
%%%
%%% Returns a normalised query map for the resolution pipeline:
%%%
%%%     #{id            := non_neg_integer(),
%%%       qname         := binary(),     % lowercase, FQDN with trailing .
%%%       qtype         := atom(),       % a, aaaa, srv, txt, tlsa, ptr, ns, soa, ...
%%%       qclass        := in,
%%%       flags         := map(),        % aa, tc, rd, cd, ad, ra, opcode, rcode
%%%       edns0         := map() | undefined,
%%%       wire_size     := pos_integer(),
%%%       ...}
%%% @end
-module(parse_query).

-export([parse/1]).

-type query() :: map().
-export_type([query/0]).

-spec parse(binary()) -> {ok, query()} | {error, term()}.
parse(_Bin) ->
    {error, parse_query_not_yet_implemented}.
