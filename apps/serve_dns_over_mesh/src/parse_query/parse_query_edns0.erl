%%% @doc EDNS0 OPT pseudo-RR decoder. Extracts UDP payload size,
%%% extended rcode bits, EDNS version, DO flag, and any EDE codes
%%% the client included.
%%%
%%% Phase 0: stub. RFC 6891 + RFC 8914.
%%% @end
-module(parse_query_edns0).

-export([decode_opt/1]).

-spec decode_opt(binary()) -> {ok, map()} | {error, term()}.
decode_opt(_OptRdata) ->
    {error, parse_query_edns0_not_yet_implemented}.
