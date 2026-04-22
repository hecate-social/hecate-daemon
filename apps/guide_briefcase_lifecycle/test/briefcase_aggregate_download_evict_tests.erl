%%% @doc State-transition tests for Phase E download + evict
%%% lifecycle on the briefcase aggregate.
%%%
%%% Covers the execute/2 gates only — no crypto, no network. Execute
%%% returns early with the right error atom on each invalid
%%% transition. The happy paths (which require mesh + CEK lookup)
%%% are exercised in integration tests.
-module(briefcase_aggregate_download_evict_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_briefcase_lifecycle/include/briefcase_state.hrl").
-include_lib("guide_briefcase_lifecycle/include/briefcase_status.hrl").

%%====================================================================
%% download_file_v1 gate
%%====================================================================

download_requires_announced_test() ->
    %% status = 0, i.e. nothing has been established about this file.
    State = briefcase_state:new(<<"file-1">>),
    Payload = download_payload(<<"file-1">>),
    ?assertEqual({error, not_announced},
                 briefcase_aggregate:execute(State, Payload)).

download_rejected_if_locally_uploaded_test() ->
    State0 = briefcase_state:new(<<"file-2">>),
    State = with_flag(State0, ?FILE_UPLOADED),
    Payload = download_payload(<<"file-2">>),
    ?assertEqual({error, locally_uploaded},
                 briefcase_aggregate:execute(State, Payload)).

download_rejected_if_already_cached_test() ->
    State0 = briefcase_state:new(<<"file-3">>),
    State = with_flags(State0, [?FILE_ANNOUNCED, ?FILE_CACHED]),
    Payload = download_payload(<<"file-3">>),
    ?assertEqual({error, already_cached},
                 briefcase_aggregate:execute(State, Payload)).

%%====================================================================
%% evict_file_v1 gate
%%====================================================================

evict_rejected_if_not_cached_test() ->
    State0 = briefcase_state:new(<<"file-4">>),
    State = with_flag(State0, ?FILE_ANNOUNCED),
    Payload = evict_payload(<<"file-4">>),
    ?assertEqual({error, not_cached},
                 briefcase_aggregate:execute(State, Payload)).

evict_on_fresh_state_rejected_test() ->
    State = briefcase_state:new(<<"file-5">>),
    Payload = evict_payload(<<"file-5">>),
    ?assertEqual({error, not_cached},
                 briefcase_aggregate:execute(State, Payload)).

%%====================================================================
%% State folds
%%====================================================================

apply_file_cached_sets_flag_test() ->
    State0 = briefcase_state:new(<<"file-6">>),
    Cached = #{event_type => <<"file_cached_v1">>,
               file_id    => <<"file-6">>,
               cache_size => 1024,
               frames     => 1,
               source_realm => <<"io.macula">>,
               cached_at  => 1234},
    State = briefcase_aggregate:apply(State0, Cached),
    ?assert(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_CACHED)).

apply_file_evicted_clears_flag_test() ->
    State0 = briefcase_state:new(<<"file-7">>),
    State1 = with_flag(State0, ?FILE_CACHED),
    Evicted = #{event_type => <<"file_evicted_v1">>,
                file_id    => <<"file-7">>,
                evicted_at => 2000},
    State2 = briefcase_aggregate:apply(State1, Evicted),
    ?assertNot(evoq_bit_flags:has(State2#briefcase_state.status, ?FILE_CACHED)).

%%====================================================================
%% Helpers
%%====================================================================

download_payload(FileId) ->
    #{command_type => download_file_v1,
      file_id      => FileId}.

evict_payload(FileId) ->
    #{command_type => evict_file_v1,
      file_id      => FileId}.

with_flag(State, Flag) ->
    State#briefcase_state{
        status = evoq_bit_flags:set(State#briefcase_state.status, Flag)
    }.

with_flags(State, Flags) ->
    lists:foldl(fun(F, S) -> with_flag(S, F) end, State, Flags).
