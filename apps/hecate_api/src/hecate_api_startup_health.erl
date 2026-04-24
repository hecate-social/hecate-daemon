%%%-------------------------------------------------------------------
%%% @doc Minimal boot-time health handler.
%%%
%%% Used during phase 1 startup when only the socket is up but domain
%%% apps have not yet loaded. Returns ready:false with boot progress
%%% from the boot tracker (if available).
%%%
%%% This handler is replaced by hecate_api_health once the boot tracker
%%% hot-swaps the full route table onto the listener.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_startup_health).

-export([init/2]).

init(Req0, State) ->
    BootStatus = boot_status(),
    Response = #{
        status => <<"starting">>,
        ready => false,
        service => <<"hecate">>,
        version => <<"0.1.0">>,
        uptime_seconds => element(1, erlang:statistics(wall_clock)) div 1000,
        boot => BootStatus
    },
    Body = json:encode(Response),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>}, Body, Req0),
    {ok, Req, State}.

boot_status() ->
    try boot_daemon:get_status()
    catch _:_ ->
        #{boot_phase => <<"initializing">>,
          stores => #{},
          stores_ready => 0,
          stores_total => 0,
          elapsed_ms => 0}
    end.
