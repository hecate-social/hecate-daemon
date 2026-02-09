%%% @doc Tests for tui_facts_stream_api pg helper
%%%
%%% HTTP-level SSE testing belongs in the e2e script.
%%% These tests verify the pg scope helper is idempotent.
%%% @end
-module(tui_facts_stream_api_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SCOPE, pg).
-define(GROUP, tui_connections).

%% Test that ensure_pg_scope is idempotent — calling twice succeeds
ensure_pg_scope_idempotent_test() ->
    %% First call starts (or confirms already started)
    Result1 = ensure_pg_scope(),
    ?assertEqual(ok, Result1),

    %% Second call also succeeds
    Result2 = ensure_pg_scope(),
    ?assertEqual(ok, Result2).

%% Test that tui_connections group can be joined and queried
tui_connections_group_test() ->
    ensure_pg_scope(),

    %% Group should be empty initially (or contain only leftover processes)
    ok = pg:join(?SCOPE, ?GROUP, self()),
    Members = pg:get_members(?SCOPE, ?GROUP),
    ?assert(lists:member(self(), Members)),

    %% Cleanup
    ok = pg:leave(?SCOPE, ?GROUP, self()).

%%% ===================================================================
%%% Helpers (mirrors tui_facts_stream_api:ensure_pg_scope/0)
%%% ===================================================================

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
