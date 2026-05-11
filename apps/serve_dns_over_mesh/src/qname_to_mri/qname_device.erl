%%% @doc Per-type rule for MRI type `device'. Delegates to qname_simple.
%%%
%%% Example: `[<<"cab-01">>], [<<"citypower">>, <<"macula">>, <<"io">>]'
%%% → `mri:device:io.macula/citypower/cab-01'.
%%% @end
-module(qname_device).

-export([resolve/2]).

-spec resolve(Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve(Left, Right) ->
    qname_simple:resolve(device, Left, Right).
