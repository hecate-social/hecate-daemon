%%% @doc Per-type rule for MRI type `service'. Delegates to qname_simple.
%%%
%%% Example: `[<<"api">>, <<"counter">>], [<<"acme">>, <<"macula">>, <<"io">>]'
%%% → `mri:service:io.macula/acme/counter/api'.
%%% @end
-module(qname_service).

-export([resolve/2]).

-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve(Left, Right) ->
    qname_simple:resolve(service, Left, Right).
