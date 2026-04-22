-module(briefcase_viewstate_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test the action set + guard view computation. Mocks
%% project_briefcase_files_store + hecate_license_guard so the test
%% doesn't need ReckonDB or live shared keys.

setup() ->
    meck:new(hecate_license_guard, [passthrough]),
    meck:new(project_briefcase_files_store, [passthrough]),
    ok.

cleanup(_) ->
    meck:unload(hecate_license_guard),
    meck:unload(project_briefcase_files_store),
    ok.

viewstate_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun local_row_actions/1,
      fun remote_with_guard_ok/1,
      fun remote_with_guard_refused/1,
      fun downloading_row/1,
      fun cached_with_guard_ok/1,
      fun cached_with_guard_refused/1,
      fun list_sorts_by_uploaded_at/1]}.

local_row_actions(_) ->
    fun() ->
        Row = base_row(<<"local-1">>, <<"local">>, <<"io.macula">>, 100),
        View = briefcase_viewstate:compute_row(Row),
        ?assertEqual(not_applicable,
                     maps:get(state, maps:get(guard, View))),
        Ids = action_ids(View),
        ?assertEqual([<<"open">>, <<"share">>, <<"unshare">>], Ids)
    end.

remote_with_guard_ok(_) ->
    fun() ->
        meck:expect(hecate_license_guard, can_open_file,
                    fun(_, _) -> ok end),
        Row = base_row(<<"r-1">>, <<"remote">>, <<"io.macula">>, 200),
        View = briefcase_viewstate:compute_row(Row),
        ?assertEqual(ok, maps:get(state, maps:get(guard, View))),
        ?assertEqual([<<"download">>, <<"info">>], action_ids(View))
    end.

remote_with_guard_refused(_) ->
    fun() ->
        meck:expect(hecate_license_guard, can_open_file,
                    fun(_, _) -> {error, no_license} end),
        Row = base_row(<<"r-2">>, <<"remote">>, <<"io.macula">>, 300),
        View = briefcase_viewstate:compute_row(Row),
        Guard = maps:get(guard, View),
        ?assertEqual(refused, maps:get(state, Guard)),
        ?assertEqual(no_license, maps:get(reason, Guard)),
        ?assertEqual([<<"info">>], action_ids(View))
    end.

downloading_row(_) ->
    fun() ->
        Row = base_row(<<"d-1">>, <<"downloading">>, <<"io.macula">>, 400),
        View = briefcase_viewstate:compute_row(Row),
        Ids = action_ids(View),
        ?assert(lists:member(<<"progress">>, Ids)),
        ?assert(lists:member(<<"cancel_download">>, Ids))
    end.

cached_with_guard_ok(_) ->
    fun() ->
        meck:expect(hecate_license_guard, can_open_file,
                    fun(_, _) -> ok end),
        Row = base_row(<<"c-1">>, <<"cached">>, <<"io.macula">>, 500),
        View = briefcase_viewstate:compute_row(Row),
        ?assertEqual([<<"open">>, <<"evict">>], action_ids(View))
    end.

cached_with_guard_refused(_) ->
    fun() ->
        meck:expect(hecate_license_guard, can_open_file,
                    fun(_, _) -> {error, license_state_stale} end),
        Row = base_row(<<"c-2">>, <<"cached">>, <<"io.macula">>, 600),
        View = briefcase_viewstate:compute_row(Row),
        Ids = action_ids(View),
        %% Open is gone (license refused); evict still available so
        %% the user can drop policy-violating ciphertext.
        ?assertNot(lists:member(<<"open">>, Ids)),
        ?assert(lists:member(<<"evict">>, Ids))
    end.

list_sorts_by_uploaded_at(_) ->
    fun() ->
        meck:expect(project_briefcase_files_store, list,
                    fun() ->
                        {ok, [base_row(<<"a">>, <<"local">>, <<"io.macula">>, 100),
                              base_row(<<"b">>, <<"local">>, <<"io.macula">>, 300),
                              base_row(<<"c">>, <<"local">>, <<"io.macula">>, 200)]}
                    end),
        {ok, Views} = briefcase_viewstate:list_files(),
        Ids = [maps:get(file_id, V) || V <- Views],
        ?assertEqual([<<"b">>, <<"c">>, <<"a">>], Ids)
    end.

%%--------------------------------------------------------------------
%% helpers
%%--------------------------------------------------------------------

base_row(FileId, Presence, Realm, UploadedAt) ->
    #{file_id     => FileId,
      realm       => Realm,
      presence    => Presence,
      privacy     => <<"shared">>,
      status      => 1,
      status_label => <<"Test">>,
      uploaded_at => UploadedAt,
      mime_type   => <<"text/plain">>,
      size        => 1024,
      path        => <<"/tmp/", FileId/binary>>,
      author_did  => <<"mri:agent:io.macula/test">>}.

action_ids(View) ->
    [maps:get(id, A) || A <- maps:get(available_actions, View)].
