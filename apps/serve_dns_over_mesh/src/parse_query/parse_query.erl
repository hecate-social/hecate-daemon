%%% @doc RFC 1035 wire decoder for DNS query messages, plus EDNS0
%%% OPT pseudo-RR detection (RFC 6891).
%%%
%%% Decodes the 12-byte header, the question section (first
%%% question only — DNS queries carry exactly one in practice),
%%% and scans the additional section for an OPT pseudo-RR
%%% (delegated to `parse_query_edns0').
%%%
%%% Returns a normalised query map for the resolution pipeline:
%%%
%%%   #{id        := non_neg_integer(),     %% echo back in the reply
%%%     opcode    := non_neg_integer(),     %% 0 = standard QUERY
%%%     rd        := boolean(),             %% recursion-desired (echoed back)
%%%     qname     := binary(),              %% lowercase, FQDN with trailing dot
%%%     qtype     := atom() | non_neg_integer(),  %% a|aaaa|srv|txt|tlsa|ptr|ns|soa|...
%%%     qclass    := in | non_neg_integer(),
%%%     edns0     := #{udp_size := pos_integer(),
%%%                    version  := non_neg_integer(),
%%%                    do       := boolean()} | undefined,
%%%     wire_size := pos_integer()}
%%%
%%% Compression pointers in the QNAME are tolerated (queries rarely
%%% compress, but some clients do).
%%% @end
-module(parse_query).

-export([parse/1, qtype_atom/1, qtype_value/1, decode_name/2]).

-type query() :: map().
-export_type([query/0]).

-define(TYPE_OPT, 41).
-define(MAX_NAME_JUMPS, 64).

%%====================================================================
%% Public API
%%====================================================================

-spec parse(binary()) -> {ok, query()} | {error, atom()}.
parse(Bin) when is_binary(Bin), byte_size(Bin) >= 12 ->
    <<Id:16, Flags:16, QdCount:16, _AnCount:16, _NsCount:16, ArCount:16,
      Rest/binary>> = Bin,
    Opcode = (Flags bsr 11) band 16#0F,
    Rd     = (Flags bsr 8) band 1 =:= 1,
    case QdCount of
        0 -> {error, no_question};
        _ ->
            case decode_question(Rest, Bin) of
                {ok, QName, QType, QClass, AfterQuestion} ->
                    Edns0 = scan_for_opt(AfterQuestion, ArCount, Bin),
                    {ok, #{id        => Id,
                           opcode    => Opcode,
                           rd        => Rd,
                           qname     => QName,
                           qtype     => qtype_atom(QType),
                           qclass    => qclass_atom(QClass),
                           edns0     => Edns0,
                           wire_size => byte_size(Bin)}};
                {error, _} = E ->
                    E
            end
    end;
parse(_) ->
    {error, malformed_packet}.

%%====================================================================
%% Question section
%%====================================================================

decode_question(Bin, Full) ->
    case decode_name(Bin, Full) of
        {ok, Name, AfterName} when byte_size(AfterName) >= 4 ->
            <<QType:16, QClass:16, AfterQuestion/binary>> = AfterName,
            {ok, normalise_qname(Name), QType, QClass, AfterQuestion};
        {ok, _Name, _AfterName} ->
            {error, truncated_question};
        {error, _} = E ->
            E
    end.

%% Lowercase + ensure a single trailing dot. decode_name returns
%% "label1.label2..." with NO trailing dot; root is the empty
%% binary.
normalise_qname(<<>>)  -> <<".">>;
normalise_qname(Name)  ->
    Lower = string:lowercase(Name),
    <<Lower/binary, ".">>.

%%====================================================================
%% Name decoding (length-prefixed labels + compression pointers)
%%====================================================================

%% @doc Decode a DNS name starting at `Bin'. `Full' is the whole
%% packet (needed to follow 0xC0 compression pointers). Returns
%% `{ok, NameBinary, RestAfterName}' — the Rest is the slice of
%% `Bin' immediately after the name's terminator (or the 2-byte
%% pointer), NOT after wherever a pointer jumped to. Exposed so
%% callers (synthesis fixtures, tests) can reuse it.
-spec decode_name(binary(), binary()) ->
    {ok, binary(), binary()} | {error, atom()}.
decode_name(Bin, Full) ->
    decode_labels(Bin, Full, [], 0).

decode_labels(_Bin, _Full, _Acc, Jumps) when Jumps > ?MAX_NAME_JUMPS ->
    {error, name_pointer_loop};
decode_labels(<<0, Rest/binary>>, _Full, Acc, _Jumps) ->
    {ok, join_labels(lists:reverse(Acc)), Rest};
decode_labels(<<2#11:2, PtrHi:6, PtrLo:8, Rest/binary>>, Full, Acc, Jumps) ->
    Offset = (PtrHi bsl 8) bor PtrLo,
    case Full of
        <<_:Offset/binary, Pointed/binary>> ->
            case decode_labels(Pointed, Full, Acc, Jumps + 1) of
                {ok, Name, _PointedRest} -> {ok, Name, Rest};
                {error, _} = E           -> E
            end;
        _ ->
            {error, bad_name_pointer}
    end;
decode_labels(<<Len:8, Label:Len/binary, Rest/binary>>, Full, Acc, Jumps)
  when Len =< 63 ->
    decode_labels(Rest, Full, [Label | Acc], Jumps);
decode_labels(_, _, _, _) ->
    {error, malformed_name}.

join_labels([])     -> <<>>;
join_labels(Labels) -> iolist_to_binary(lists:join(<<".">>, Labels)).

%%====================================================================
%% EDNS0 OPT pseudo-RR scan in the additional section
%%====================================================================

scan_for_opt(_Bin, 0, _Full) ->
    undefined;
scan_for_opt(Bin, Count, Full) when Count > 0 ->
    case decode_rr(Bin, Full) of
        {ok, #{type := ?TYPE_OPT, class := UdpSize, ttl := Ttl, rdata := Rdata}, _Rest} ->
            Version = (Ttl bsr 16) band 16#FF,
            Do      = (Ttl bsr 15) band 1 =:= 1,
            Base = #{udp_size => max(UdpSize, 512), version => Version, do => Do},
            case parse_query_edns0:decode_opt(Rdata) of
                {ok, OptExtra} -> maps:merge(Base, OptExtra);
                {error, _}     -> Base
            end;
        {ok, _OtherRr, Rest} ->
            scan_for_opt(Rest, Count - 1, Full);
        {error, _} ->
            undefined
    end.

decode_rr(Bin, Full) ->
    case decode_name(Bin, Full) of
        {ok, _Name, AfterName} when byte_size(AfterName) >= 10 ->
            <<Type:16, Class:16, Ttl:32, RdLen:16, AfterFixed/binary>> = AfterName,
            case AfterFixed of
                <<Rdata:RdLen/binary, Rest/binary>> ->
                    {ok, #{type => Type, class => Class, ttl => Ttl,
                           rdata => Rdata}, Rest};
                _ ->
                    {error, truncated_rr}
            end;
        {ok, _, _} ->
            {error, truncated_rr};
        {error, _} = E ->
            E
    end.

%%====================================================================
%% QTYPE / QCLASS mapping
%%====================================================================

%% @doc Map a numeric DNS TYPE to an atom (or pass the number
%% through for unknown types).
-spec qtype_atom(non_neg_integer()) -> atom() | non_neg_integer().
qtype_atom(1)   -> a;
qtype_atom(2)   -> ns;
qtype_atom(5)   -> cname;
qtype_atom(6)   -> soa;
qtype_atom(12)  -> ptr;
qtype_atom(15)  -> mx;
qtype_atom(16)  -> txt;
qtype_atom(28)  -> aaaa;
qtype_atom(33)  -> srv;
qtype_atom(41)  -> opt;
qtype_atom(52)  -> tlsa;
qtype_atom(251) -> ixfr;
qtype_atom(252) -> axfr;
qtype_atom(255) -> any;
qtype_atom(N) when is_integer(N) -> N.

%% @doc Map a qtype atom back to its numeric value.
-spec qtype_value(atom() | non_neg_integer()) -> non_neg_integer().
qtype_value(a)     -> 1;
qtype_value(ns)    -> 2;
qtype_value(cname) -> 5;
qtype_value(soa)   -> 6;
qtype_value(ptr)   -> 12;
qtype_value(mx)    -> 15;
qtype_value(txt)   -> 16;
qtype_value(aaaa)  -> 28;
qtype_value(srv)   -> 33;
qtype_value(opt)   -> 41;
qtype_value(tlsa)  -> 52;
qtype_value(ixfr)  -> 251;
qtype_value(axfr)  -> 252;
qtype_value(any)   -> 255;
qtype_value(N) when is_integer(N) -> N.

qclass_atom(1) -> in;
qclass_atom(N) -> N.
