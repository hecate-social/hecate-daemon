%%%-------------------------------------------------------------------
%%% @doc Health check endpoint.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_health).

-export([init/2, routes/0]).

routes() -> [{"/health", ?MODULE, []}].

init(Req0, State) ->
    DaemonState = hecate_lifecycle:get_state(),
    Response = #{
        status => lifecycle_status(DaemonState),
        ready => DaemonState =:= running,
        service => <<"hecate">>,
        version => app_version(),
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

lifecycle_status(running) -> <<"healthy">>;
lifecycle_status(starting) -> <<"starting">>;
lifecycle_status(stopping) -> <<"stopping">>;
lifecycle_status(_) -> <<"starting">>.

app_version() ->
    case application:get_key(hecate, vsn) of
        {ok, Vsn} -> list_to_binary(Vsn);
        undefined -> <<"unknown">>
    end.
