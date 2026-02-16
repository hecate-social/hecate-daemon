%%%-------------------------------------------------------------------
%%% @doc Minimal boot-time health handler.
%%%
%%% Used during phase 1 startup when only the socket is up but domain
%%% apps have not yet loaded. Returns ready:false so clients know the
%%% daemon is alive but not yet fully operational.
%%%
%%% This handler is replaced by hecate_api_health once hecate_api_app
%%% hot-swaps the full route table onto the listener.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_startup_health).

-export([init/2]).

init(Req0, State) ->
    Response = #{
        status => <<"starting">>,
        ready => false,
        service => <<"hecate">>,
        version => <<"0.1.0">>,
        uptime_seconds => element(1, erlang:statistics(wall_clock)) div 1000
    },
    Body = json:encode(Response),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>}, Body, Req0),
    {ok, Req, State}.
