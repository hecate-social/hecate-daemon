%%% @doc Tests for web_events_stream_api pg helper
%%%
%%% HTTP-level SSE testing belongs in the e2e script.
%%% These tests verify the pg scope helper is idempotent
%%% and that the web_connections group works correctly.
%%% @end
-module(web_events_stream_api_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SCOPE, pg).
-define(GROUP, web_connections).

%% Test that ensure_pg_scope is idempotent
ensure_pg_scope_idempotent_test() ->
    Result1 = ensure_pg_scope(),
    ?assertEqual(ok, Result1),
    Result2 = ensure_pg_scope(),
    ?assertEqual(ok, Result2).

%% Test that web_connections group can be joined and queried
web_connections_group_test() ->
    ensure_pg_scope(),
    ok = pg:join(?SCOPE, ?GROUP, self()),
    Members = pg:get_members(?SCOPE, ?GROUP),
    ?assert(lists:member(self(), Members)),
    ok = pg:leave(?SCOPE, ?GROUP, self()).

%%% ===================================================================
%%% Helpers (mirrors web_events_stream_api:ensure_pg_scope/0)
%%% ===================================================================

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
