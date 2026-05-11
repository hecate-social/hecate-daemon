%%% @doc RFC 1035 wire encoder for DNS response messages.
%%%
%%% Takes a response spec, echoes the original question, packs the
%%% answer/authority/additional sections, appends the EDNS0 OPT
%%% pseudo-RR (with an EDE option via `compose_ede') when the
%%% query advertised EDNS0, and sets TC=1 + drops the body when
%%% the response would exceed the client's UDP buffer.
%%%
%%% Response spec:
%%%   #{query      := parse_query:query(),  %% for id, qname, qtype, rd, edns0
%%%     rcode      := noerror | formerr | servfail | nxdomain | notimp | refused,
%%%     aa         := boolean(),            %% authoritative-answer flag
%%%     answers    := [rr()],
%%%     authority  := [rr()],               %% optional, default []
%%%     additional := [rr()],               %% optional, default [] (OPT is added separately)
%%%     ede        := atom() | tuple() | none,   %% EDE cause; `none' = no EDE option
%%%     ede_detail := binary() | undefined,
%%%     truncate   := boolean()}            %% optional, default false; force TC=1
%%%
%%% rr() :: #{name := binary(),             %% FQDN; trailing dot optional
%%%           type := atom() | non_neg_integer(),
%%%           class := in,                  %% optional, default in
%%%           ttl  := non_neg_integer(),
%%%           rdata := rdata_spec()}        %% see encode_rdata/2
%%%
%%% Names are written out fully (no compression) — slightly larger
%%% packets but correct; compression is a Phase 2 optimisation.
%%% @end
-module(compose_response).

-export([compose/1, encode_name/1]).

-define(TYPE_OPT, 41).
%% Our advertised EDNS0 UDP receive size (the modern safe default).
-define(OUR_UDP_SIZE, 1232).
%% Bare DNS (no EDNS0) caps responses at 512 octets.
-define(BARE_UDP_LIMIT, 512).

%%====================================================================
%% Public API
%%====================================================================

-spec compose(ResponseSpec :: map()) -> {ok, binary()} | {error, atom()}.
compose(#{query := Q} = Spec) ->
    Edns0     = maps:get(edns0, Q, undefined),
    MaxSize   = max_response_size(Edns0),
    Question  = encode_question(Q),
    Answers   = maps:get(answers, Spec, []),
    Authority = maps:get(authority, Spec, []),
    Additional= maps:get(additional, Spec, []),
    EdeCause  = maps:get(ede, Spec, none),
    EdeDetail = maps:get(ede_detail, Spec, undefined),
    ForceTc   = maps:get(truncate, Spec, false),
    OptRr     = opt_rr(Edns0, EdeCause, EdeDetail),
    %% First attempt: full body.
    Full = assemble(Q, Spec, Question, Answers, Authority, Additional, OptRr, false),
    case ForceTc orelse byte_size(Full) > MaxSize of
        false ->
            {ok, Full};
        true ->
            %% Truncate: drop answer + authority RRs, keep header +
            %% question + (OPT if any), set TC=1.
            Truncated = assemble(Q, Spec, Question, [], [], [], OptRr, true),
            {ok, Truncated}
    end;
compose(_) ->
    {error, missing_query}.

%%====================================================================
%% Assembly
%%====================================================================

assemble(Q, Spec, Question, Answers, Authority, Additional, OptRr, Tc) ->
    Id     = maps:get(id, Q, 0),
    Opcode = maps:get(opcode, Q, 0),
    Rd     = maps:get(rd, Q, false),
    Rcode  = rcode_value(maps:get(rcode, Spec, noerror)),
    Aa     = maps:get(aa, Spec, false),
    AdditionalAll = Additional ++ opt_list(OptRr),
    AnCount = length(Answers),
    NsCount = length(Authority),
    ArCount = length(AdditionalAll),
    Flags = build_flags(Opcode, Aa, Tc, Rd, Rcode),
    Header = <<Id:16, Flags:16, 1:16, AnCount:16, NsCount:16, ArCount:16>>,
    Body = [Question,
            [encode_rr(RR) || RR <- Answers],
            [encode_rr(RR) || RR <- Authority],
            [encode_rr_or_opt(RR) || RR <- AdditionalAll]],
    iolist_to_binary([Header, Body]).

%% QR=1 always; the bit layout is QR(1) Opcode(4) AA(1) TC(1) RD(1)
%% RA(1) Z(3) RCODE(4). We never recurse → RA=0; Z=0.
build_flags(Opcode, Aa, Tc, Rd, Rcode) ->
    (1 bsl 15)
        bor ((Opcode band 16#0F) bsl 11)
        bor (bit(Aa) bsl 10)
        bor (bit(Tc) bsl 9)
        bor (bit(Rd) bsl 8)
        bor (0 bsl 7)              %% RA
        bor (Rcode band 16#0F).

bit(true)  -> 1;
bit(false) -> 0.

opt_list(<<>>) -> [];
opt_list(Bin)  -> [{opt, Bin}].

encode_rr_or_opt({opt, Bin}) -> Bin;
encode_rr_or_opt(RR)         -> encode_rr(RR).

%%====================================================================
%% Question section (echo the original)
%%====================================================================

encode_question(Q) ->
    QName  = maps:get(qname, Q, <<".">>),
    QType  = parse_query:qtype_value(maps:get(qtype, Q, a)),
    QClass = 1,    %% IN
    [encode_name(QName), <<QType:16, QClass:16>>].

%%====================================================================
%% Resource records
%%====================================================================

encode_rr(#{name := Name, type := Type, ttl := Ttl, rdata := RdataSpec} = RR) ->
    Class  = class_value(maps:get(class, RR, in)),
    TypeN  = parse_query:qtype_value(Type),
    Rdata  = encode_rdata(Type, RdataSpec),
    [encode_name(Name),
     <<TypeN:16, Class:16, Ttl:32, (byte_size(Rdata)):16>>,
     Rdata].

class_value(in) -> 1;
class_value(N) when is_integer(N) -> N.

%% Per-type RDATA encoding.
encode_rdata(a, {A, B, C, D}) ->
    <<A, B, C, D>>;
encode_rdata(a, Bin) when is_binary(Bin), byte_size(Bin) =:= 4 ->
    Bin;
encode_rdata(aaaa, {G1,G2,G3,G4,G5,G6,G7,G8}) ->
    <<G1:16, G2:16, G3:16, G4:16, G5:16, G6:16, G7:16, G8:16>>;
encode_rdata(aaaa, Bin) when is_binary(Bin), byte_size(Bin) =:= 16 ->
    Bin;
encode_rdata(txt, Strings) when is_list(Strings) ->
    iolist_to_binary([txt_string(S) || S <- Strings]);
encode_rdata(srv, {Prio, Weight, Port, Target}) ->
    <<Prio:16, Weight:16, Port:16, (encode_name(Target))/binary>>;
encode_rdata(ptr, Name) when is_binary(Name) ->
    encode_name(Name);
encode_rdata(ns, Name) when is_binary(Name) ->
    encode_name(Name);
encode_rdata(cname, Name) when is_binary(Name) ->
    encode_name(Name);
encode_rdata(soa, {Mname, Rname, Serial, Refresh, Retry, Expire, Minimum}) ->
    <<(encode_name(Mname))/binary, (encode_name(Rname))/binary,
      Serial:32, Refresh:32, Retry:32, Expire:32, Minimum:32>>;
encode_rdata(tlsa, {Usage, Selector, MatchType, CertData}) ->
    <<Usage:8, Selector:8, MatchType:8, CertData/binary>>;
encode_rdata(_OtherType, Bin) when is_binary(Bin) ->
    %% Unknown / raw RDATA: pass through.
    Bin.

%% A TXT character-string is a single length octet (0..255) then
%% that many bytes. Strings longer than 255 are split into chunks.
txt_string(S) when is_binary(S), byte_size(S) =< 255 ->
    <<(byte_size(S)):8, S/binary>>;
txt_string(S) when is_binary(S) ->
    <<Chunk:255/binary, Rest/binary>> = S,
    [<<255:8, Chunk/binary>>, txt_string(Rest)].

%%====================================================================
%% Name encoding (no compression)
%%====================================================================

%% @doc Encode a DNS name (FQDN, with or without trailing dot) as
%% length-prefixed labels terminated by a zero octet. Root (`.'
%% or empty) → just the zero octet. Exposed so RDATA encoders
%% (SRV target, SOA mname/rname, etc.) can reuse it.
-spec encode_name(binary()) -> binary().
encode_name(<<>>)    -> <<0>>;
encode_name(<<".">>) -> <<0>>;
encode_name(Name) when is_binary(Name) ->
    Trimmed = case binary:last(Name) of
                  $. -> binary:part(Name, 0, byte_size(Name) - 1);
                  _  -> Name
              end,
    Labels = binary:split(Trimmed, <<".">>, [global]),
    iolist_to_binary([encode_label(L) || L <- Labels, L =/= <<>>] ++ [<<0>>]).

encode_label(L) when byte_size(L) =< 63 ->
    <<(byte_size(L)):8, L/binary>>;
encode_label(L) ->
    %% RFC 1035: a label is at most 63 octets. Truncate defensively
    %% rather than emit an invalid packet.
    <<Trunc:63/binary, _/binary>> = L,
    <<63:8, Trunc/binary>>.

%%====================================================================
%% EDNS0 OPT pseudo-RR (only emitted when the query carried one)
%%====================================================================

opt_rr(undefined, _EdeCause, _EdeDetail) ->
    <<>>;
opt_rr(_Edns0, EdeCause, EdeDetail) ->
    RData = compose_ede:option(EdeCause, EdeDetail),
    %% NAME=root(0x00), TYPE=OPT(41), CLASS=our UDP size,
    %% TTL = extended-rcode(0) << 24 | version(0) << 16 | flags(0).
    <<0:8, ?TYPE_OPT:16, ?OUR_UDP_SIZE:16, 0:32, (byte_size(RData)):16, RData/binary>>.

%%====================================================================
%% Sizing + rcode
%%====================================================================

max_response_size(undefined) -> ?BARE_UDP_LIMIT;
max_response_size(#{udp_size := N}) when is_integer(N), N >= ?BARE_UDP_LIMIT -> N;
max_response_size(_) -> ?BARE_UDP_LIMIT.

rcode_value(noerror)  -> 0;
rcode_value(formerr)  -> 1;
rcode_value(servfail) -> 2;
rcode_value(nxdomain) -> 3;
rcode_value(notimp)   -> 4;
rcode_value(refused)  -> 5;
rcode_value(N) when is_integer(N), N >= 0, N =< 15 -> N.
