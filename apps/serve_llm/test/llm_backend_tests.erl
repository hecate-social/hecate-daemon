%%%-------------------------------------------------------------------
%%% @doc Tests for llm_backend module.
%%% @end
%%%-------------------------------------------------------------------
-module(llm_backend_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

llm_backend_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"chat returns response on success", fun chat_success/0},
            {"chat returns error on HTTP failure", fun chat_http_error/0},
            {"chat returns error on connection failure", fun chat_connection_error/0},
            {"list_models returns parsed models", fun list_models_success/0},
            {"list_models returns error on failure", fun list_models_error/0},
            {"health returns ok on success", fun health_success/0},
            {"health returns error on failure", fun health_error/0},
            {"chat respects temperature option", fun chat_with_temperature/0},
            {"chat respects max_tokens option", fun chat_with_max_tokens/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    meck:new(hackney, [passthrough]),
    ok.

cleanup(_) ->
    meck:unload(hackney),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

chat_success() ->
    %% Mock successful Ollama response
    OllamaResponse = #{
        <<"model">> => <<"llama3.2">>,
        <<"message">> => #{
            <<"role">> => <<"assistant">>,
            <<"content">> => <<"Hello! How can I help you?">>
        },
        <<"done">> => true,
        <<"total_duration">> => 1234567890,
        <<"prompt_eval_count">> => 10,
        <<"eval_count">> => 15
    },

    meck:expect(hackney, post, fun(_Url, _Headers, _Body, _Opts) ->
        {ok, 200, [], iolist_to_binary(json:encode(OllamaResponse))}
    end),

    Messages = [#{role => <<"user">>, content => <<"Hello!">>}],
    Opts = #{model => <<"llama3.2">>},

    {ok, Response} = llm_backend:chat(<<"http://localhost:11434">>, Messages, Opts),

    ?assertEqual(<<"Hello! How can I help you?">>, maps:get(content, Response)),
    ?assertEqual(<<"llama3.2">>, maps:get(model, Response)),
    ?assertEqual(true, maps:get(done, Response)),
    ?assertEqual(15, maps:get(eval_count, Response)).

chat_http_error() ->
    meck:expect(hackney, post, fun(_Url, _Headers, _Body, _Opts) ->
        {ok, 500, [], <<"Internal Server Error">>}
    end),

    Messages = [#{role => <<"user">>, content => <<"Hello!">>}],
    Opts = #{model => <<"llama3.2">>},

    Result = llm_backend:chat(<<"http://localhost:11434">>, Messages, Opts),

    ?assertMatch({error, {http_error, 500, _}}, Result).

chat_connection_error() ->
    meck:expect(hackney, post, fun(_Url, _Headers, _Body, _Opts) ->
        {error, econnrefused}
    end),

    Messages = [#{role => <<"user">>, content => <<"Hello!">>}],
    Opts = #{model => <<"llama3.2">>},

    Result = llm_backend:chat(<<"http://localhost:11434">>, Messages, Opts),

    ?assertEqual({error, econnrefused}, Result).

list_models_success() ->
    %% Mock Ollama /api/tags response
    OllamaResponse = #{
        <<"models">> => [
            #{
                <<"name">> => <<"llama3.2:latest">>,
                <<"size">> => 2000000000,
                <<"modified_at">> => <<"2024-01-15T10:30:00Z">>,
                <<"digest">> => <<"sha256:abc123">>
            },
            #{
                <<"name">> => <<"qwen2.5-coder:7b">>,
                <<"size">> => 4000000000,
                <<"modified_at">> => <<"2024-01-14T08:00:00Z">>,
                <<"digest">> => <<"sha256:def456">>
            }
        ]
    },

    meck:expect(hackney, get, fun(_Url, _Headers, _Body, _Opts) ->
        {ok, 200, [], iolist_to_binary(json:encode(OllamaResponse))}
    end),

    {ok, Models} = llm_backend:list_models(<<"http://localhost:11434">>),

    ?assertEqual(2, length(Models)),
    [Model1, Model2] = Models,
    ?assertEqual(<<"llama3.2:latest">>, maps:get(name, Model1)),
    ?assertEqual(<<"qwen2.5-coder:7b">>, maps:get(name, Model2)),
    ?assertEqual(2000000000, maps:get(size, Model1)).

list_models_error() ->
    meck:expect(hackney, get, fun(_Url, _Headers, _Body, _Opts) ->
        {error, timeout}
    end),

    Result = llm_backend:list_models(<<"http://localhost:11434">>),

    ?assertEqual({error, timeout}, Result).

health_success() ->
    meck:expect(hackney, get, fun(_Url, _Headers, _Body, _Opts) ->
        {ok, 200, [], <<"{\"models\":[]}">>}
    end),

    Result = llm_backend:health(<<"http://localhost:11434">>),

    ?assertEqual(ok, Result).

health_error() ->
    meck:expect(hackney, get, fun(_Url, _Headers, _Body, _Opts) ->
        {error, econnrefused}
    end),

    Result = llm_backend:health(<<"http://localhost:11434">>),

    ?assertEqual({error, econnrefused}, Result).

chat_with_temperature() ->
    meck:expect(hackney, post, fun(_Url, _Headers, Body, _Opts) ->
        Decoded = json:decode(iolist_to_binary(Body)),
        Options = maps:get(<<"options">>, Decoded, #{}),
        %% Verify temperature is passed in options
        ?assertEqual(0.7, maps:get(<<"temperature">>, Options)),
        {ok, 200, [], iolist_to_binary(json:encode(#{
            <<"model">> => <<"llama3.2">>,
            <<"message">> => #{<<"content">> => <<"test">>},
            <<"done">> => true
        }))}
    end),

    Messages = [#{role => <<"user">>, content => <<"Hello!">>}],
    Opts = #{model => <<"llama3.2">>, temperature => 0.7},

    {ok, _Response} = llm_backend:chat(<<"http://localhost:11434">>, Messages, Opts).

chat_with_max_tokens() ->
    meck:expect(hackney, post, fun(_Url, _Headers, Body, _Opts) ->
        Decoded = json:decode(iolist_to_binary(Body)),
        Options = maps:get(<<"options">>, Decoded, #{}),
        %% Ollama uses num_predict instead of max_tokens
        ?assertEqual(100, maps:get(<<"num_predict">>, Options)),
        {ok, 200, [], iolist_to_binary(json:encode(#{
            <<"model">> => <<"llama3.2">>,
            <<"message">> => #{<<"content">> => <<"test">>},
            <<"done">> => true
        }))}
    end),

    Messages = [#{role => <<"user">>, content => <<"Hello!">>}],
    Opts = #{model => <<"llama3.2">>, max_tokens => 100},

    {ok, _Response} = llm_backend:chat(<<"http://localhost:11434">>, Messages, Opts).
