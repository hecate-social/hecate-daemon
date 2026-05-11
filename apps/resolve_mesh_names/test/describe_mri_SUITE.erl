%%% @doc CT suite for the describe_mri desk. PLAN PART1 §4.1.
%%%
%%% Coverage:
%%%   - station MRI describe → records populated, partial=true
%%%     (endorsements + backlinks are follow-ups)
%%%   - unresolvable MRI → records=[], partial=true
%%%   - composite shape is always well-formed (all keys present)
%%%   - last_modified reflects the resolved records' observed_at
%%% @end
-module(describe_mri_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    describe_station_includes_records/1,
    describe_unresolvable_mri_is_partial/1,
    composite_shape_is_well_formed/1
]).

all() ->
    [
        describe_station_includes_records,
        describe_unresolvable_mri_is_partial,
        composite_shape_is_well_formed
    ].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    cleanup([trust_anchors, cache_records, cache_invalidate, cache_ttl_sweep,
             lookup_dedup, lookup_via_dht, verify_trust_chain, resolve_mri,
             backlinks, describe_mri]),
    {ok, _} = trust_anchors:start_link(),
    {ok, _} = cache_records:start_link(),
    {ok, _} = cache_invalidate:start_link(),
    application:set_env(resolve_mesh_names, cache_ttl_sweep_period_ms, 60000),
    {ok, _} = cache_ttl_sweep:start_link(),
    {ok, _} = lookup_dedup:start_link(),
    {ok, _} = lookup_via_dht:start_link(),
    {ok, _} = verify_trust_chain:start_link(),
    {ok, _} = resolve_mri:start_link(),
    {ok, _} = backlinks:start_link(),
    {ok, _} = describe_mri:start_link(),
    Config.

end_per_testcase(_TC, _Config) ->
    cleanup([describe_mri, backlinks, resolve_mri, verify_trust_chain,
             lookup_via_dht, lookup_dedup, cache_ttl_sweep, cache_invalidate,
             cache_records, trust_anchors]),
    application:unset_env(resolve_mesh_names, cache_ttl_sweep_period_ms),
    ok.

cleanup(Names) ->
    [case whereis(N) of
         undefined -> ok;
         Pid       -> catch gen_server:stop(Pid, normal, 1000)
     end || N <- Names],
    ok.

%%====================================================================
%% Helpers
%%====================================================================

make_station() ->
    St   = macula_identity:generate(),
    StPk = macula_identity:public(St),
    Z32  = macula_z32:encode(StPk),
    Mri  = <<"mri:station:", Z32/binary>>,
    Rec  = macula_record:sign(
             macula_record:station_endpoint(StPk, 4433,
                                            #{host_advertised => [<<"::1">>]}),
             St),
    {Mri, StPk, Rec, macula_record:storage_key(Rec)}.

stub(Map) ->
    fun(_P, K) -> case maps:get(K, Map, undefined) of
                      undefined -> {error, not_found};
                      Rec       -> {ok, Rec}
                  end
    end.

%%====================================================================
%% Tests
%%====================================================================

describe_station_includes_records(_Config) ->
    {Mri, _Pk, Rec, Key} = make_station(),
    Find = stub(#{Key => Rec}),
    {ok, Desc} = describe_mri:describe(self(), Mri,
                                       #{find_fn => Find, max_attempts => 1}),
    #{mri          := Mri,
      records      := [#{record_type := station_endpoint}],
      endorsements := [],
      backlinks    := [],
      consensus    := #{replicas := 1, agreed := 1},
      partial      := true} = Desc,   %% partial because endorsements+backlinks deferred
    %% last_modified is the resolved record's observed_at (> 0).
    LM = maps:get(last_modified, Desc),
    true = (LM > 0),
    ok.

describe_unresolvable_mri_is_partial(_Config) ->
    {ok, Mri} = macula_mri:new(user, <<"io.x">>, [<<"acme">>, <<"alice">>]),
    {ok, Desc} = describe_mri:describe(self(), Mri, #{}),
    #{mri      := Mri,
      records  := [],
      partial  := true,
      last_modified := 0} = Desc,
    ok.

composite_shape_is_well_formed(_Config) ->
    {ok, Mri} = macula_mri:new(user, <<"io.x">>, [<<"acme">>, <<"bob">>]),
    {ok, Desc} = describe_mri:describe(self(), Mri, #{}),
    true = is_map(Desc),
    %% Exactly the documented keys, no more, no less.
    Expected = lists:sort([mri, records, endorsements, backlinks, consensus,
                           last_modified, partial]),
    Expected = lists:sort(maps:keys(Desc)),
    Mri          = maps:get(mri, Desc),
    true         = is_list(maps:get(records, Desc)),
    true         = is_list(maps:get(endorsements, Desc)),
    true         = is_list(maps:get(backlinks, Desc)),
    #{replicas := _, agreed := _} = maps:get(consensus, Desc),
    true         = is_integer(maps:get(last_modified, Desc)),
    true         = is_boolean(maps:get(partial, Desc)),
    ok.
