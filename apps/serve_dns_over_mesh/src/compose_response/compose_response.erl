%%% @doc Wire encoder for DNS response messages. Sets rcode, AA/TC/
%%% RD/RA flags, packs the answer/authority/additional sections,
%%% appends the EDNS0 OPT pseudo-RR (with EDE codes via
%%% `compose_ede') when the query advertised EDNS0 support, sets
%%% TC=1 if the response would exceed the client's UDP buffer.
%%%
%%% Phase 0: stub.
%%% @end
-module(compose_response).

-export([compose/1]).

-spec compose(map()) -> {ok, binary()} | {error, atom()}.
compose(_ResponseSpec) ->
    {error, compose_response_not_yet_implemented}.
