%%% @doc Per-type rule for MRI type `user'. Delegates to qname_simple
%%% — the algebra is the standard "reverse(path) + reverse(realm)"
%%% per PLAN_DNS_OVER_MESH_PART1 §3.1.
%%%
%%% Example: `[<<"alice">>], [<<"acme">>, <<"macula">>, <<"io">>]'
%%% → `mri:user:io.macula/acme/alice'.
%%% @end
-module(qname_user).

-export([resolve/2]).

-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve(Left, Right) ->
    qname_simple:resolve(user, Left, Right).
