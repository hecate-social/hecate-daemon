%%% @doc DoH endpoint — RFC 8484 (DNS Queries over HTTPS). A plain
%%% Cowboy handler mounted at `/dns-query' on the daemon's existing
%%% HTTP server (auto-discovered: `hecate_api_routes' scans every
%%% listed hecate app for a module exporting `routes/0', and
%%% `serve_dns_over_mesh' is in that list).
%%%
%%% Unlike listen_udp / listen_tcp this is NOT a process — DoH is
%%% request-driven, Cowboy invokes `init/2' per request — so there's
%%% no gen_server and no supervision; the module just exists and
%%% exports its route.
%%%
%%% Request forms (RFC 8484 §4.1):
%%%   POST /dns-query           body = raw DNS wire message
%%%                             (Content-Type: application/dns-message)
%%%   GET  /dns-query?dns=<b64url-no-padding(DNS wire message)>
%%%
%%% Response: 200, `Content-Type: application/dns-message', body =
%%% raw DNS wire response. `Cache-Control: no-store' for now —
%%% deriving max-age from the answer's minimum TTL (RFC 8484 §5.1)
%%% is a follow-up. A malformed DNS message → 400; a method other
%%% than GET/POST → 405; a GET without a valid `dns' param → 400.
%%%
%%% The macula client pool is fetched lazily via
%%% `hecate_mesh:get_client/0' (caught — when the mesh isn't
%%% connected, serve_query answers mesh queries SERVFAIL and
%%% non-mesh REFUSED, neither needing a pool).
%%% @end
-module(listen_doh).

-export([init/2, routes/0]).

-define(CT_DNS_MESSAGE, <<"application/dns-message">>).

%% @doc Cowboy route table entry — discovered + compiled by
%% `hecate_api_routes:compile/0'.
-spec routes() -> [{string(), module(), term()}].
routes() ->
    Path = doh_path(),
    [{Path, ?MODULE, []}].

doh_path() ->
    case application:get_env(serve_dns_over_mesh, doh_path, "/dns-query") of
        P when is_list(P)   -> P;
        P when is_binary(P) -> binary_to_list(P)
    end.

%%====================================================================
%% Cowboy handler
%%====================================================================

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    {DnsMsg, Req1} = extract_query(Method, Req0),
    case DnsMsg of
        {ok, Bin} ->
            Pool = mesh_pool(),
            case serve_query:handle(Pool, Bin, #{}) of
                {ok, RespBin} ->
                    {ok, reply_dns(200, RespBin, Req1), State};
                drop ->
                    {ok, reply_text(400, <<"malformed DNS message">>, Req1), State}
            end;
        {error, bad_request} ->
            {ok, reply_text(400, <<"missing or invalid dns parameter">>, Req1), State};
        {error, method_not_allowed} ->
            {ok, reply_text(405, <<"use GET or POST">>, Req1), State}
    end.

%%--------------------------------------------------------------------
%% Extract the raw DNS wire message from the request.
%%--------------------------------------------------------------------

extract_query(<<"POST">>, Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case Body of
        <<>> -> {{error, bad_request}, Req1};
        _    -> {{ok, Body}, Req1}
    end;
extract_query(<<"GET">>, Req0) ->
    Qs = cowboy_req:parse_qs(Req0),
    case lists:keyfind(<<"dns">>, 1, Qs) of
        {<<"dns">>, B64} when is_binary(B64), byte_size(B64) > 0 ->
            case base64url_decode(B64) of
                {ok, Bin} -> {{ok, Bin}, Req0};
                error     -> {{error, bad_request}, Req0}
            end;
        _ ->
            {{error, bad_request}, Req0}
    end;
extract_query(_OtherMethod, Req0) ->
    {{error, method_not_allowed}, Req0}.

%% base64url, no padding (RFC 4648 §5). Pad to a multiple of 4
%% then decode with the urlsafe alphabet.
base64url_decode(B) ->
    Padded = case byte_size(B) rem 4 of
                 0 -> B;
                 2 -> <<B/binary, "==">>;
                 3 -> <<B/binary, "=">>;
                 _ -> B    %% length ≡ 1 mod 4 is invalid base64; let decode fail
             end,
    case catch base64:decode(Padded, #{mode => urlsafe}) of
        Bin when is_binary(Bin) -> {ok, Bin};
        _                       -> error
    end.

%%--------------------------------------------------------------------
%% Replies
%%--------------------------------------------------------------------

reply_dns(Status, Body, Req) ->
    cowboy_req:reply(Status,
                     #{<<"content-type">>  => ?CT_DNS_MESSAGE,
                       <<"cache-control">> => <<"no-store">>},
                     Body, Req).

reply_text(Status, Body, Req) ->
    cowboy_req:reply(Status,
                     #{<<"content-type">> => <<"text/plain; charset=utf-8">>},
                     Body, Req).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

mesh_pool() ->
    case catch hecate_mesh:get_client() of
        {ok, Pool} when is_pid(Pool) -> Pool;
        _                            -> undefined
    end.
