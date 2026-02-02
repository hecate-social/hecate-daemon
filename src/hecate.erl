%%%-------------------------------------------------------------------
%%% @doc Hecate main module - escript entry point.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate).

-export([main/1]).

%% escript entry point
main(Args) ->
    hecate_cli:main(Args).
