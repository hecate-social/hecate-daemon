%%% @doc Projection: phase_transitioned_v1 -> cartwheels table (UPDATE current_phase + status)
-module(phase_transitioned_v1_to_cartwheels).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{cartwheel_id := PId, to_phase := ToPhase} = E) ->
    StatusFlag = phase_to_status_flag(ToPhase),
    Sql = "UPDATE cartwheels SET current_phase = ?1, status = status | ?2, "
          "phase_started_at = ?3 WHERE cartwheel_id = ?4",
    query_cartwheels_store:execute(Sql, [
        ToPhase,
        StatusFlag,
        maps:get(transitioned_at, E, erlang:system_time(millisecond)),
        PId
    ]).

%% Internal

phase_to_status_flag(<<"discovery_n_analysis">>) -> 2;
phase_to_status_flag(<<"architecture_n_planning">>) -> 8;
phase_to_status_flag(<<"testing_n_implementation">>) -> 32;
phase_to_status_flag(<<"deployment_n_operations">>) -> 128;
phase_to_status_flag(_) -> 0.
