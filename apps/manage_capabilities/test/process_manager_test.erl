%%% @doc Tests for LLM Process Manager logic
%%% Tests the pure command-building logic without needing live stores.
-module(process_manager_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% announce_capability_v1 command creation (what PM builds)
%% ===================================================================

pm_builds_valid_announce_command_test() ->
    %% Simulate what the PM builds from an llm_detected_v1 event
    CmdParams = #{
        capability_mri => <<"mri:capability:llm/llama3.2">>,
        agent_identity => <<"mri:agent:io.macula/hecate-dev">>,
        tags => [<<"llm">>, <<"chat">>, <<"ai">>],
        description => <<"LLM capability: llama3.2 (llama family, 4096 context)">>,
        metadata => #{
            type => <<"llm">>,
            model => #{
                name => <<"llama3.2">>,
                context_length => 4096,
                quantization => <<"q4_K_M">>,
                parameter_count => <<"3B">>,
                family => <<"llama">>,
                size_bytes => 2000000000
            },
            hardware => #{
                ram_gb => 16,
                cpu_cores => 4,
                gpu => <<"none">>,
                gpu_vram_gb => 0,
                storage_path => <<"/bulk0">>
            },
            status => #{
                queue_depth => 0,
                avg_tokens_per_sec => 0.0,
                available => true
            }
        }
    },
    {ok, Cmd} = announce_capability_v1:new(CmdParams),
    ?assertEqual(<<"mri:capability:llm/llama3.2">>, announce_capability_v1:get_mri(Cmd)),
    ?assertEqual(<<"mri:agent:io.macula/hecate-dev">>, announce_capability_v1:get_agent_id(Cmd)),

    %% Verify metadata carries rich info
    Meta = announce_capability_v1:get_metadata(Cmd),
    ?assertEqual(<<"llm">>, maps:get(type, Meta)),
    ?assert(maps:is_key(model, Meta)),
    ?assert(maps:is_key(hardware, Meta)),
    ?assert(maps:is_key(status, Meta)),

    %% Model info
    Model = maps:get(model, Meta),
    ?assertEqual(<<"llama3.2">>, maps:get(name, Model)),
    ?assertEqual(4096, maps:get(context_length, Model)),

    %% Hardware info
    Hardware = maps:get(hardware, Meta),
    ?assertEqual(16, maps:get(ram_gb, Hardware)).

%% ===================================================================
%% retract_capability_v1 command creation (what retract PM builds)
%% ===================================================================

pm_builds_valid_retract_command_test() ->
    {ok, Cmd} = retract_capability_v1:new(
        <<"mri:capability:llm/llama3.2">>,
        <<"mri:agent:io.macula/hecate-dev">>,
        <<"model_removed">>
    ),
    ?assertEqual(<<"mri:capability:llm/llama3.2">>, retract_capability_v1:get_mri(Cmd)).

%% ===================================================================
%% update_capability_v1 command creation (what status PM builds)
%% ===================================================================

pm_builds_valid_update_command_test() ->
    CmdParams = #{
        capability_mri => <<"mri:capability:llm/llama3.2">>,
        agent_identity => <<"mri:agent:io.macula/hecate-dev">>,
        metadata => #{
            type => <<"llm">>,
            status => #{
                available => true,
                queue_depth => 2,
                avg_tokens_per_sec => 45.2
            }
        }
    },
    {ok, Cmd} = update_capability_v1:new(CmdParams),
    ?assertEqual(<<"mri:capability:llm/llama3.2">>, update_capability_v1:get_mri(Cmd)),
    Meta = update_capability_v1:get_metadata(Cmd),
    ?assertEqual(<<"llm">>, maps:get(type, Meta)),
    Status = maps:get(status, Meta),
    ?assertEqual(true, maps:get(available, Status)),
    ?assertEqual(2, maps:get(queue_depth, Status)).

%% ===================================================================
%% MRI sanitization (model name → capability MRI)
%% ===================================================================

mri_sanitization_test() ->
    %% Model names with colons should be sanitized
    ?assertEqual(<<"mri:capability:llm/llama3.2">>,
        build_capability_mri(<<"llama3.2">>)),
    ?assertEqual(<<"mri:capability:llm/llama3.1-70b">>,
        build_capability_mri(<<"llama3.1:70b">>)),
    ?assertEqual(<<"mri:capability:llm/qwen2.5-coder-7b">>,
        build_capability_mri(<<"qwen2.5-coder:7b">>)).

%% Helper - mirrors PM logic
build_capability_mri(ModelName) ->
    SafeName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
    <<"mri:capability:llm/", SafeName/binary>>.
