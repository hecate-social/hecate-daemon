%%% @doc Per-type rule for MRI type `app'. Delegates to qname_simple.
%%%
%%% Example: `[<<"counter">>], [<<"acme">>, <<"macula">>, <<"io">>]'
%%% → `mri:app:io.macula/acme/counter'.
%%% @end
-module(qname_app).

-export([resolve/2]).

-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve(Left, Right) ->
    qname_simple:resolve(app, Left, Right).
