%%% @doc Tests for serve_llm event modules
-module(llm_events_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% llm_detected_v1 tests
%% ===================================================================

detected_event_creation_test() ->
    ModelInfo = #{
        name => <<"llama3.2">>,
        context_length => 4096,
        family => <<"llama">>
    },
    {ok, Event} = llm_detected_v1:new(<<"llama3.2">>, ModelInfo),
    ?assertEqual(<<"llama3.2">>, llm_detected_v1:model_name(Event)),
    ?assertEqual(ModelInfo, llm_detected_v1:model_info(Event)),
    ?assert(is_integer(llm_detected_v1:detected_at(Event))).

detected_event_serialization_test() ->
    ModelInfo = #{name => <<"qwen2.5">>, family => <<"qwen">>},
    {ok, Event} = llm_detected_v1:new(<<"qwen2.5">>, ModelInfo),
    Map = llm_detected_v1:to_map(Event),

    ?assertEqual(<<"qwen2.5">>, maps:get(model_name, Map)),
    ?assertEqual(ModelInfo, maps:get(model_info, Map)),
    ?assert(maps:is_key(detected_at, Map)),

    {ok, Event2} = llm_detected_v1:from_map(Map),
    ?assertEqual(llm_detected_v1:model_name(Event), llm_detected_v1:model_name(Event2)).

%% ===================================================================
%% llm_removed_v1 tests
%% ===================================================================

removed_event_creation_test() ->
    {ok, Event} = llm_removed_v1:new(<<"llama3.2">>),
    ?assertEqual(<<"llama3.2">>, llm_removed_v1:model_name(Event)),
    ?assert(is_integer(llm_removed_v1:removed_at(Event))).

removed_event_serialization_test() ->
    {ok, Event} = llm_removed_v1:new(<<"codellama">>),
    Map = llm_removed_v1:to_map(Event),
    {ok, Event2} = llm_removed_v1:from_map(Map),
    ?assertEqual(llm_removed_v1:model_name(Event), llm_removed_v1:model_name(Event2)).

%% ===================================================================
%% llm_status_reported_v1 tests
%% ===================================================================

status_event_creation_test() ->
    Status = #{available => true, queue_depth => 0, avg_tokens_per_sec => 45.2},
    {ok, Event} = llm_status_reported_v1:new(<<"llama3.2">>, Status),
    ?assertEqual(<<"llama3.2">>, llm_status_reported_v1:model_name(Event)),
    ?assertEqual(Status, llm_status_reported_v1:status(Event)),
    ?assert(is_integer(llm_status_reported_v1:reported_at(Event))).

status_event_serialization_test() ->
    Status = #{available => false, queue_depth => 3},
    {ok, Event} = llm_status_reported_v1:new(<<"deepseek-r1">>, Status),
    Map = llm_status_reported_v1:to_map(Event),
    {ok, Event2} = llm_status_reported_v1:from_map(Map),
    ?assertEqual(llm_status_reported_v1:model_name(Event),
                 llm_status_reported_v1:model_name(Event2)),
    ?assertEqual(llm_status_reported_v1:status(Event),
                 llm_status_reported_v1:status(Event2)).
