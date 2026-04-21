%%% @doc EUnit tests for `post_receive_script:render/1`.
-module(post_receive_script_tests).

-include_lib("eunit/include/eunit.hrl").

render_contains_expected_pieces_test() ->
    Script = post_receive_script:render(<<"01HZYABC">>),
    ?assert(is_binary(Script)),
    ?assert(binary:match(Script, <<"#!/usr/bin/env bash">>) =/= nomatch),
    ?assert(binary:match(Script, <<"REPO_ID=\"01HZYABC\"">>) =/= nomatch),
    ?assert(binary:match(Script, <<"HECATE_REF_UPDATES_SOCK">>) =/= nomatch),
    ?assert(binary:match(Script, <<"UNIX-CONNECT">>) =/= nomatch).

render_honours_env_override_test() ->
    OldEnv = os:getenv("HECATE_REF_UPDATES_SOCK"),
    true = os:putenv("HECATE_REF_UPDATES_SOCK", "/tmp/hecate-test.sock"),
    try
        Script = post_receive_script:render(<<"rA">>),
        ?assert(binary:match(Script, <<"/tmp/hecate-test.sock">>) =/= nomatch)
    after
        restore_env("HECATE_REF_UPDATES_SOCK", OldEnv)
    end.

render_strips_dangerous_chars_test() ->
    %% A malformed repo_id containing quotes must not escape the shell
    %% variable. Our cleaner drops quotes/backslashes.
    Script = post_receive_script:render(<<"abc\"def">>),
    %% The cleaned repo id should be "abcdef".
    ?assert(binary:match(Script, <<"REPO_ID=\"abcdef\"">>) =/= nomatch).

%%====================================================================
%% Helpers
%%====================================================================

restore_env(Key, false) -> os:unsetenv(Key);
restore_env(Key, "")    -> os:unsetenv(Key);
restore_env(Key, Val)   -> os:putenv(Key, Val).
