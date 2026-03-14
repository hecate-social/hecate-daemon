%%%-------------------------------------------------------------------
%%% @doc Prometheus text exposition endpoint.
%%%
%%% Serves plugin and daemon metrics in Prometheus text format at
%%% GET /metrics. Scrapeable by Prometheus, VictoriaMetrics, etc.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_metrics).

-export([init/2, routes/0]).

routes() -> [{"/metrics", ?MODULE, []}].

init(Req0, State) ->
    Body = iolist_to_binary(render_metrics()),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"text/plain; version=0.0.4; charset=utf-8">>
    }, Body, Req0),
    {ok, Req, State}.

%%====================================================================
%% Internal
%%====================================================================

render_metrics() ->
    PluginMetrics = hecate_plugin_metrics:get_all(),
    DaemonMetrics = daemon_metrics(),
    render_plugin_metrics(PluginMetrics) ++ render_daemon_metrics(DaemonMetrics).

render_plugin_metrics(Metrics) ->
    %% Group by metric name for TYPE comments
    Grouped = lists:foldl(fun(#{name := Name, type := Type} = M, Acc) ->
        Key = {Name, Type},
        Existing = maps:get(Key, Acc, []),
        Acc#{Key => [M | Existing]}
    end, #{}, Metrics),

    maps:fold(fun({Name, Type}, Items, Acc) ->
        PromType = prom_type(Type),
        FullName = <<"hecate_plugin_", Name/binary>>,
        TypeLine = [<<"# TYPE ">>, FullName, <<" ">>, PromType, <<"\n">>],
        Lines = [format_metric(FullName, M) || M <- Items],
        [TypeLine | Lines] ++ Acc
    end, [], Grouped).

render_daemon_metrics(Metrics) ->
    lists:map(fun({Name, Type, Value}) ->
        PromType = prom_type(Type),
        [<<"# TYPE ">>, Name, <<" ">>, PromType, <<"\n">>,
         Name, <<" ">>, integer_to_binary(Value), <<"\n">>]
    end, Metrics).

format_metric(FullName, #{plugin := Plugin, value := Value}) ->
    [FullName, <<"{plugin=\"">>, Plugin, <<"\"} ">>,
     integer_to_binary(Value), <<"\n">>].

prom_type(counter) -> <<"counter">>;
prom_type(gauge) -> <<"gauge">>.

daemon_metrics() ->
    Memory = erlang:memory(),
    TotalMem = proplists:get_value(total, Memory, 0),
    ProcessCount = erlang:system_info(process_count),
    UptimeMs = element(1, erlang:statistics(wall_clock)),
    UptimeSec = UptimeMs div 1000,
    [
        {<<"hecate_daemon_memory_bytes">>, gauge, TotalMem},
        {<<"hecate_daemon_process_count">>, gauge, ProcessCount},
        {<<"hecate_daemon_uptime_seconds">>, gauge, UptimeSec}
    ].
