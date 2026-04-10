%%%-------------------------------------------------------------------
%%% @doc Health check endpoint.
%%%
%%% During boot, includes progressive boot status from the boot tracker.
%%% Once running, returns a lean health response.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_health).

-export([init/2, routes/0]).

routes() -> [{"/health", ?MODULE, []}].

init(Req0, State) ->
    DaemonState = hecate_lifecycle:get_state(),
    Response0 = #{
        status => lifecycle_status(DaemonState),
        ready => DaemonState =:= running,
        service => <<"hecate">>,
        version => app_version(),
        node_name => atom_to_binary(node()),
        site_id => guide_site_lifecycle_app:site_id(),
        uptime_seconds => element(1, erlang:statistics(wall_clock)) div 1000,
        identity => case hecate_identity:is_initialized() of
            true -> <<"initialized">>;
            false -> <<"not_initialized">>
        end
    },
    Response1 = maybe_add_boot_status(DaemonState, Response0),
    Response2 = maybe_add_mesh_proof(Response1),
    Response3 = maybe_add_plugin_health(DaemonState, Response2),
    Response = add_viewstate(Response3),
    Body = json:encode(Response),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.

maybe_add_boot_status(running, Response) ->
    Response;
maybe_add_boot_status(_NotRunning, Response) ->
    BootStatus = try hecate_boot_tracker:get_status()
                 catch _:_ ->
                     #{boot_phase => <<"initializing">>,
                       stores => #{},
                       stores_ready => 0,
                       stores_total => 0,
                       elapsed_ms => 0}
                 end,
    Response#{boot => BootStatus}.

maybe_add_mesh_proof(Response) ->
    try mesh_proof_coordinator:get_proof_results() of
        #{proof_status := Status, probes := Probes} ->
            Passed = maps:size(maps:filter(
                fun(_, #{status := S}) -> S =:= passed end, Probes)),
            Response#{mesh_proof => #{
                status => Status,
                passed => Passed,
                total => maps:size(Probes)
            }};
        _ ->
            Response
    catch _:_ -> Response
    end.

maybe_add_plugin_health(running, Response) ->
    Plugins = try hecate_plugin_loader:loaded_plugins()
              catch _:_ -> []
              end,
    PluginHealth = lists:foldl(fun(#{name := Name, callback := Cb}, Acc) ->
        Acc#{Name => plugin_health_status(Cb)}
    end, #{}, Plugins),
    Response#{plugins => PluginHealth};
maybe_add_plugin_health(_NotRunning, Response) ->
    Response.

plugin_health_status(Cb) ->
    try check_plugin_health(Cb)
    catch _:_ -> <<"unknown">>
    end.

check_plugin_health(Cb) ->
    case erlang:function_exported(Cb, health, 0) of
        false -> <<"ok">>;
        true -> format_health(Cb:health())
    end.

format_health(ok) -> <<"ok">>;
format_health(degraded) -> <<"degraded">>;
format_health({unhealthy, Reason}) -> Reason.

add_viewstate(Response) ->
    Viewstate = try hecate_viewstate:compute()
                catch _:_ -> #{}
                end,
    Response#{viewstate => Viewstate}.

lifecycle_status(running) -> <<"healthy">>;
lifecycle_status(starting) -> <<"starting">>;
lifecycle_status(stopping) -> <<"stopping">>;
lifecycle_status(_) -> <<"starting">>.

app_version() ->
    case application:get_key(hecate, vsn) of
        {ok, Vsn} -> list_to_binary(Vsn);
        undefined -> <<"unknown">>
    end.
