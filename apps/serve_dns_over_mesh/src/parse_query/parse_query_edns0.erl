%%% @doc EDNS0 OPT pseudo-RR RDATA decoder (RFC 6891 §6.1.2).
%%%
%%% The OPT RR's RDATA is a sequence of options, each:
%%%   OPTION-CODE   : 2 bytes
%%%   OPTION-LENGTH : 2 bytes
%%%   OPTION-DATA   : OPTION-LENGTH bytes
%%%
%%% We extract the options we care about — currently just any EDE
%%% codes (RFC 8914, option code 15) the client echoed back, which
%%% a resolver may log but doesn't act on. Unknown options are
%%% collected raw so the resolver can ignore-or-log them.
%%%
%%% The fixed OPT fields (UDP payload size in CLASS, extended
%%% rcode / version / DO flag in TTL) are handled by the caller
%%% (`parse_query:scan_for_opt/3') — this module sees only the
%%% RDATA blob.
%%% @end
-module(parse_query_edns0).

-export([decode_opt/1]).

-define(OPT_CODE_EDE, 15).

-spec decode_opt(OptRdata :: binary()) -> {ok, map()} | {error, atom()}.
decode_opt(Rdata) when is_binary(Rdata) ->
    case decode_options(Rdata, []) of
        {ok, Opts} ->
            EdeCodes = [{InfoCode, Text}
                        || {?OPT_CODE_EDE, <<InfoCode:16, Text/binary>>} <- Opts],
            Other    = [{Code, Data} || {Code, Data} <- Opts,
                                         Code =/= ?OPT_CODE_EDE],
            {ok, #{client_ede_codes => EdeCodes, other_opts => Other}};
        {error, _} = E ->
            E
    end;
decode_opt(_) ->
    {error, malformed_opt_rdata}.

decode_options(<<>>, Acc) ->
    {ok, lists:reverse(Acc)};
decode_options(<<Code:16, Len:16, Data:Len/binary, Rest/binary>>, Acc) ->
    decode_options(Rest, [{Code, Data} | Acc]);
decode_options(_, _) ->
    {error, truncated_opt_option}.
