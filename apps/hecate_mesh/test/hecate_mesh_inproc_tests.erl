%%% @doc Unit tests for the in-process mesh backend.
%%%
%%% Proves the swap module honours the public API of
%%% `hecate_mesh_client` enough that domain code can run unmodified:
%%% publish fan-out, subscribe/unsubscribe, unary calls, stream
%%% calls via macula_stream_local, advertisement lifecycle.
-module(hecate_mesh_inproc_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PROC, <<"test.mesh_inproc.echo">>).
-define(STREAM_PROC, <<"test.mesh_inproc.stream_echo">>).
-define(TOPIC, <<"test.mesh_inproc.topic.v1">>).

setup() ->
    {ok, _} = application:ensure_all_started(macula),
    %% Always register under hecate_mesh_client — if a stale one from
    %% a previous test is lingering, tear it down first.
    case erlang:whereis(hecate_mesh_client) of
        undefined -> ok;
        Existing ->
            try exit(Existing, shutdown) catch _:_ -> ok end,
            timer:sleep(50)
    end,
    {ok, NewPid} = hecate_mesh_inproc:start_link(),
    NewPid.

cleanup(Pid) ->
    _ = hecate_mesh_inproc:clear(),
    try gen_server:stop(Pid) catch _:_ -> ok end,
    [macula:unadvertise_stream(P)
     || {P, _} <- macula_stream_local:list_advertised()],
    ok.

backend_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun publish_fans_out_to_matching_subs/1,
      fun publish_ignores_non_matching_topic/1,
      fun unsubscribe_stops_delivery/1,
      fun unary_call_dispatches_to_advertised_handler/1,
      fun unary_call_unknown_procedure/1,
      fun advertisement_unregister_clears/1,
      fun stream_roundtrip_via_macula_local/1,
      fun activate_is_noop/1,
      fun get_status_reports_counts/1,
      fun clear_resets_everything/1]}.

publish_fans_out_to_matching_subs(_Pid) ->
    fun() ->
        Parent = self(),
        {ok, _} = hecate_mesh_inproc:subscribe(?TOPIC,
            fun(Msg) -> Parent ! {got, Msg} end),
        ok = hecate_mesh_inproc:publish(?TOPIC, #{hello => world}),
        receive {got, #{topic := ?TOPIC, payload := #{hello := world}}} -> ok
        after 500 -> erlang:error(timeout_waiting_for_delivery)
        end
    end.

publish_ignores_non_matching_topic(_Pid) ->
    fun() ->
        Parent = self(),
        {ok, _} = hecate_mesh_inproc:subscribe(<<"other.topic">>,
            fun(Msg) -> Parent ! {got, Msg} end),
        ok = hecate_mesh_inproc:publish(?TOPIC, #{}),
        receive {got, _} -> erlang:error(unexpected_delivery)
        after 200 -> ok
        end
    end.

unsubscribe_stops_delivery(_Pid) ->
    fun() ->
        Parent = self(),
        {ok, Ref} = hecate_mesh_inproc:subscribe(?TOPIC,
            fun(Msg) -> Parent ! {got, Msg} end),
        ok = hecate_mesh_inproc:unsubscribe(Ref),
        ok = hecate_mesh_inproc:publish(?TOPIC, #{}),
        receive {got, _} -> erlang:error(delivery_after_unsubscribe)
        after 200 -> ok
        end
    end.

unary_call_dispatches_to_advertised_handler(_Pid) ->
    fun() ->
        ok = hecate_mesh_inproc:register_advertisement(?PROC,
                fun(Args) -> {ok, Args#{echoed => true}} end),
        {ok, Reply} = hecate_mesh_inproc:call(?PROC,
                        #{ping => 1}, 1000),
        ?assertEqual(true, maps:get(echoed, Reply))
    end.

unary_call_unknown_procedure(_Pid) ->
    fun() ->
        ?assertEqual({error, not_advertised},
                     hecate_mesh_inproc:call(<<"nope">>, #{}, 100))
    end.

advertisement_unregister_clears(_Pid) ->
    fun() ->
        ok = hecate_mesh_inproc:register_advertisement(?PROC,
                fun(_) -> {ok, ok} end),
        {ok, _} = hecate_mesh_inproc:call(?PROC, #{}, 100),
        ok = hecate_mesh_inproc:unregister_advertisement(?PROC),
        ?assertEqual({error, not_advertised},
                     hecate_mesh_inproc:call(?PROC, #{}, 100))
    end.

stream_roundtrip_via_macula_local(_Pid) ->
    fun() ->
        ok = hecate_mesh_inproc:register_stream_advertisement(
            ?STREAM_PROC, server_stream,
            fun(Stream, _Args) ->
                macula:send(Stream, <<"chunk1">>),
                macula:send(Stream, <<"chunk2">>),
                macula:close_stream(Stream)
            end),
        {ok, Stream} = hecate_mesh_inproc:call_stream(
            ?STREAM_PROC, #{}, #{}, 1000),
        ?assertEqual({chunk, <<"chunk1">>}, macula:recv(Stream, 500)),
        ?assertEqual({chunk, <<"chunk2">>}, macula:recv(Stream, 500)),
        ?assertEqual(eof, macula:recv(Stream, 500))
    end.

activate_is_noop(_Pid) ->
    fun() ->
        ?assertEqual(ok, hecate_mesh_inproc:activate()),
        ?assertEqual(true, hecate_mesh_inproc:is_activated())
    end.

get_status_reports_counts(_Pid) ->
    fun() ->
        {ok, _} = hecate_mesh_inproc:subscribe(?TOPIC, fun(_) -> ok end),
        {ok, _} = hecate_mesh_inproc:subscribe(<<"other">>, fun(_) -> ok end),
        ok = hecate_mesh_inproc:register_advertisement(?PROC,
                fun(_) -> {ok, ok} end),
        {ok, Status} = hecate_mesh_inproc:get_status(),
        ?assertEqual(inproc, maps:get(backend, Status)),
        ?assertEqual(true, maps:get(activated, Status)),
        ?assertEqual(2, maps:get(subscriptions, Status)),
        ?assertEqual(1, maps:get(advertisements, Status))
    end.

clear_resets_everything(_Pid) ->
    fun() ->
        {ok, _} = hecate_mesh_inproc:subscribe(?TOPIC, fun(_) -> ok end),
        ok = hecate_mesh_inproc:register_advertisement(?PROC,
                fun(_) -> {ok, ok} end),
        hecate_mesh_inproc:clear(),
        {ok, Status} = hecate_mesh_inproc:get_status(),
        ?assertEqual(0, maps:get(subscriptions, Status)),
        ?assertEqual(0, maps:get(advertisements, Status)),
        ?assertEqual({error, not_advertised},
                     hecate_mesh_inproc:call(?PROC, #{}, 100))
    end.
