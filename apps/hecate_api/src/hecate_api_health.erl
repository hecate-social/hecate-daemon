%%%-------------------------------------------------------------------
%%% @doc Health check endpoint.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_health).

-export([init/2, routes/0]).

routes() -> [{"/health", ?MODULE, []}].

init(Req0, State) ->
    Response = #{
        status => <<"healthy">>,
        ready => true,
        service => <<"hecate">>,
        version => <<"0.1.0">>,
        uptime_seconds => element(1, erlang:statistics(wall_clock)) div 1000,
        identity => case hecate_identity:is_initialized() of
            true -> <<"initialized">>;
            false -> <<"not_initialized">>
        end
    },
    Body = json:encode(Response),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.
