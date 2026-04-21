%%% @doc EUnit for the stream_chat_with_llm bridge.
%%%
%%% Drives the handler against macula_stream_local (Phase 1 dispatch
%%% path) so we exercise the SDK + the bridge logic without needing
%%% a live mesh connection. The test "provider" is a small spawned
%%% process that mimics chat_to_llm's per-token message protocol —
%%% {llm_chunk, Ref, Map} | {llm_done, Ref} | {llm_error, Ref, R}.
-module(stream_chat_with_llm_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PROC, <<"test.llm.chat_stream">>).

setup() ->
    {ok, _} = application:ensure_all_started(macula),
    %% Wipe any prior advertisements
    [macula:unadvertise_stream(P)
     || {P, _} <- macula_stream_local:list_advertised()],
    ok.

teardown(_) ->
    [macula:unadvertise_stream(P)
     || {P, _} <- macula_stream_local:list_advertised()],
    ok.

with_setup(Tests) ->
    {setup, fun setup/0, fun teardown/1, Tests}.

%%% ===================================================================
%%% Tests
%%%
%%% The bridge handler reads {llm_chunk,...} messages from its own
%%% mailbox, so the test's "fake chat_to_llm" simply sends those to
%%% the handler PID. We wire the handler ourselves rather than going
%%% through chat_to_llm:chat_stream/3 (which would launch a real
%%% provider HTTP request).
%%% ===================================================================

server_stream_forwards_chunks_test_() ->
    with_setup([
        {"3 chunks then done flows from provider into the macula stream",
         fun() ->
             ok = advertise_with_fake_chat([
                 {chunk, #{<<"delta">> => <<"hel">>}},
                 {chunk, #{<<"delta">> => <<"lo">>}},
                 {chunk, #{<<"delta">> => <<" world">>}},
                 done
             ]),

             {ok, S} = macula:call_stream(?PROC, args()),

             ?assertEqual({data, #{<<"delta">> => <<"hel">>}},
                          macula:recv(S, 1000)),
             ?assertEqual({data, #{<<"delta">> => <<"lo">>}},
                          macula:recv(S, 1000)),
             ?assertEqual({data, #{<<"delta">> => <<" world">>}},
                          macula:recv(S, 1000)),
             ?assertEqual(eof, macula:recv(S, 1000))
         end},
        {"provider error aborts the stream",
         fun() ->
             ok = advertise_with_fake_chat([
                 {chunk, #{<<"delta">> => <<"part">>}},
                 {error, <<"upstream timeout">>}
             ]),
             {ok, S} = macula:call_stream(?PROC, args()),
             ?assertEqual({data, #{<<"delta">> => <<"part">>}},
                          macula:recv(S, 1000)),
             ?assertMatch({error, {<<"llm_error">>, _}},
                          macula:recv(S, 1000))
         end},
        {"missing model field aborts as bad_request",
         fun() ->
             ok = macula:advertise_stream(?PROC, server_stream,
                  fun(Stream, Args) ->
                      stream_chat_with_llm:handle(Stream, Args)
                  end),
             {ok, S} = macula:call_stream(?PROC, #{<<"messages">> => []}),
             ?assertMatch({error, {<<"bad_request">>, _}},
                          macula:recv(S, 1000))
         end}
    ]).

%%% ===================================================================
%%% Helpers
%%%
%%% advertise_with_fake_chat installs a stream handler that mimics the
%%% real one's structure but replaces chat_to_llm:chat_stream/3 with a
%%% spawned process that emits the given Script of messages.
%%% ===================================================================

advertise_with_fake_chat(Script) ->
    macula:advertise_stream(?PROC, server_stream,
        fun(Stream, _Args) ->
            Self = self(),
            Ref = make_ref(),
            spawn(fun() -> emit_script(Self, Ref, Script) end),
            run_bridge_loop(Stream, Ref)
        end).

%% Mirror of stream_chat_with_llm:bridge_loop/2 — kept inline so the
%% test exercises the exact same shape without needing to expose the
%% private function.
run_bridge_loop(Stream, Ref) ->
    receive
        {llm_chunk, Ref, ChunkMap} ->
            case macula:send(Stream, ChunkMap, msgpack) of
                ok -> run_bridge_loop(Stream, Ref);
                {error, _} -> ok
            end;
        {llm_done, Ref} ->
            macula:close(Stream),
            ok;
        {llm_error, Ref, Reason} ->
            macula:abort(Stream, <<"llm_error">>, fmt(Reason)),
            ok
    after 2000 ->
        macula:abort(Stream, <<"timeout">>, <<"test idle">>),
        ok
    end.

emit_script(_Caller, _Ref, []) -> ok;
emit_script(Caller, Ref, [{chunk, Map} | Rest]) ->
    Caller ! {llm_chunk, Ref, Map},
    emit_script(Caller, Ref, Rest);
emit_script(Caller, Ref, [done | _Rest]) ->
    Caller ! {llm_done, Ref};
emit_script(Caller, Ref, [{error, R} | _Rest]) ->
    Caller ! {llm_error, Ref, R}.

args() ->
    #{<<"model">> => <<"test-model">>,
      <<"messages">> => [#{<<"role">> => <<"user">>,
                           <<"content">> => <<"hi">>}]}.

fmt(B) when is_binary(B) -> B;
fmt(A) when is_atom(A) -> atom_to_binary(A, utf8);
fmt(X) -> iolist_to_binary(io_lib:format("~p", [X])).
