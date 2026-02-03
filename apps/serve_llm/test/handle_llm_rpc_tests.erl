%%%-------------------------------------------------------------------
%%% @doc Tests for handle_llm_rpc module.
%%% @end
%%%-------------------------------------------------------------------
-module(handle_llm_rpc_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

handle_llm_rpc_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"handles chat action successfully", fun chat_action_success/0},
            {"handles chat action error", fun chat_action_error/0},
            {"handles list_models action", fun list_models_action/0},
            {"handles health action when healthy", fun health_action_healthy/0},
            {"handles health action when unhealthy", fun health_action_unhealthy/0},
            {"handles unknown action", fun unknown_action/0},
            {"does not send response when no reply_to", fun no_reply_to/0},
            {"reports request to status heartbeat", fun reports_to_heartbeat/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    meck:new(llm_backend, [passthrough]),
    meck:new(hecate_mesh_client, [passthrough]),
    meck:new(llm_status_heartbeat, [passthrough]),

    %% Default mock for mesh publish - capture calls
    meck:expect(hecate_mesh_client, publish, fun(_Topic, _Payload) ->
        ok
    end),

    %% Default mock for heartbeat reporting
    meck:expect(llm_status_heartbeat, report_request, fun(_Model) -> ok end),
    meck:expect(llm_status_heartbeat, report_completion, fun(_Model, _Tokens) -> ok end),

    ok.

cleanup(_) ->
    meck:unload(llm_backend),
    meck:unload(hecate_mesh_client),
    meck:unload(llm_status_heartbeat),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

chat_action_success() ->
    %% Mock llm_backend to return success
    meck:expect(llm_backend, chat, fun(_Messages, _Opts) ->
        {ok, #{
            content => <<"Hello there!">>,
            model => <<"llama3.2">>,
            done => true,
            eval_count => 10
        }}
    end),

    %% Track published response
    Self = self(),
    meck:expect(hecate_mesh_client, publish, fun(Topic, Payload) ->
        Self ! {published, Topic, Payload},
        ok
    end),

    Payload = #{
        <<"action">> => <<"chat">>,
        <<"model">> => <<"llama3.2">>,
        <<"messages">> => [#{<<"role">> => <<"user">>, <<"content">> => <<"Hi">>}],
        <<"reply_to">> => <<"response.topic.123">>
    },

    ok = handle_llm_rpc:handle_request(<<"req-001">>, Payload, <<"agent-id">>),

    receive
        {published, Topic, Response} ->
            ?assertEqual(<<"response.topic.123">>, Topic),
            ?assertEqual(<<"req-001">>, maps:get(<<"request_id">>, Response)),
            ?assertEqual(<<"ok">>, maps:get(<<"status">>, Response)),
            Result = maps:get(<<"result">>, Response),
            ?assertEqual(<<"Hello there!">>, maps:get(content, Result))
    after 1000 ->
        ?assert(false, "No response published")
    end.

chat_action_error() ->
    meck:expect(llm_backend, chat, fun(_Messages, _Opts) ->
        {error, econnrefused}
    end),

    Self = self(),
    meck:expect(hecate_mesh_client, publish, fun(Topic, Payload) ->
        Self ! {published, Topic, Payload},
        ok
    end),

    Payload = #{
        <<"action">> => <<"chat">>,
        <<"model">> => <<"llama3.2">>,
        <<"messages">> => [],
        <<"reply_to">> => <<"response.topic">>
    },

    ok = handle_llm_rpc:handle_request(<<"req-002">>, Payload, <<"agent-id">>),

    receive
        {published, _Topic, Response} ->
            ?assertEqual(<<"error">>, maps:get(<<"status">>, Response)),
            ?assertEqual(<<"econnrefused">>, maps:get(<<"error">>, Response))
    after 1000 ->
        ?assert(false, "No error response published")
    end.

list_models_action() ->
    meck:expect(llm_backend, list_models, fun() ->
        {ok, [
            #{name => <<"llama3.2">>, size => 2000000000},
            #{name => <<"qwen2.5">>, size => 4000000000}
        ]}
    end),

    Self = self(),
    meck:expect(hecate_mesh_client, publish, fun(Topic, Payload) ->
        Self ! {published, Topic, Payload},
        ok
    end),

    Payload = #{
        <<"action">> => <<"list_models">>,
        <<"reply_to">> => <<"response.topic">>
    },

    ok = handle_llm_rpc:handle_request(<<"req-003">>, Payload, <<"agent-id">>),

    receive
        {published, _Topic, Response} ->
            ?assertEqual(<<"ok">>, maps:get(<<"status">>, Response)),
            Result = maps:get(<<"result">>, Response),
            Models = maps:get(<<"models">>, Result),
            ?assertEqual(2, length(Models))
    after 1000 ->
        ?assert(false, "No response published")
    end.

health_action_healthy() ->
    meck:expect(llm_backend, health, fun() -> ok end),

    Self = self(),
    meck:expect(hecate_mesh_client, publish, fun(Topic, Payload) ->
        Self ! {published, Topic, Payload},
        ok
    end),

    Payload = #{
        <<"action">> => <<"health">>,
        <<"reply_to">> => <<"response.topic">>
    },

    ok = handle_llm_rpc:handle_request(<<"req-004">>, Payload, <<"agent-id">>),

    receive
        {published, _Topic, Response} ->
            ?assertEqual(<<"ok">>, maps:get(<<"status">>, Response)),
            Result = maps:get(<<"result">>, Response),
            ?assertEqual(<<"healthy">>, maps:get(<<"status">>, Result))
    after 1000 ->
        ?assert(false, "No response published")
    end.

health_action_unhealthy() ->
    meck:expect(llm_backend, health, fun() -> {error, econnrefused} end),

    Self = self(),
    meck:expect(hecate_mesh_client, publish, fun(Topic, Payload) ->
        Self ! {published, Topic, Payload},
        ok
    end),

    Payload = #{
        <<"action">> => <<"health">>,
        <<"reply_to">> => <<"response.topic">>
    },

    ok = handle_llm_rpc:handle_request(<<"req-005">>, Payload, <<"agent-id">>),

    receive
        {published, _Topic, Response} ->
            ?assertEqual(<<"error">>, maps:get(<<"status">>, Response))
    after 1000 ->
        ?assert(false, "No response published")
    end.

unknown_action() ->
    Self = self(),
    meck:expect(hecate_mesh_client, publish, fun(Topic, Payload) ->
        Self ! {published, Topic, Payload},
        ok
    end),

    Payload = #{
        <<"action">> => <<"invalid_action">>,
        <<"reply_to">> => <<"response.topic">>
    },

    ok = handle_llm_rpc:handle_request(<<"req-006">>, Payload, <<"agent-id">>),

    receive
        {published, _Topic, Response} ->
            ?assertEqual(<<"error">>, maps:get(<<"status">>, Response)),
            ?assertEqual(<<"unknown_action">>, maps:get(<<"error">>, Response))
    after 1000 ->
        ?assert(false, "No response published")
    end.

no_reply_to() ->
    %% When no reply_to, should not attempt to publish
    meck:expect(llm_backend, health, fun() -> ok end),

    %% Make publish fail to detect if it's called
    meck:expect(hecate_mesh_client, publish, fun(_Topic, _Payload) ->
        error(should_not_be_called)
    end),

    Payload = #{
        <<"action">> => <<"health">>
        %% No reply_to field
    },

    %% Should complete without error (no publish attempted)
    ok = handle_llm_rpc:handle_request(<<"req-007">>, Payload, <<"agent-id">>).

reports_to_heartbeat() ->
    Self = self(),

    meck:expect(llm_status_heartbeat, report_request, fun(Model) ->
        Self ! {report_request, Model},
        ok
    end),

    meck:expect(llm_status_heartbeat, report_completion, fun(Model, Tokens) ->
        Self ! {report_completion, Model, Tokens},
        ok
    end),

    meck:expect(llm_backend, chat, fun(_Messages, _Opts) ->
        {ok, #{
            content => <<"Response">>,
            model => <<"llama3.2">>,
            done => true,
            <<"eval_count">> => 42
        }}
    end),

    Payload = #{
        <<"action">> => <<"chat">>,
        <<"model">> => <<"llama3.2">>,
        <<"messages">> => [],
        <<"reply_to">> => <<"response.topic">>
    },

    ok = handle_llm_rpc:handle_request(<<"req-008">>, Payload, <<"agent-id">>),

    receive
        {report_request, Model} ->
            ?assertEqual(<<"llama3.2">>, Model)
    after 1000 ->
        ?assert(false, "report_request not called")
    end,

    receive
        {report_completion, Model2, _Tokens} ->
            ?assertEqual(<<"llama3.2">>, Model2)
    after 1000 ->
        ?assert(false, "report_completion not called")
    end.
