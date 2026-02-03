%%% @doc LLM RPC Handler
%%% Handles incoming LLM RPC requests from the mesh.
%%% Routes to llm_backend and sends response back via mesh.
-module(handle_llm_rpc).

-export([handle_request/3]).

%% Suppress dialyzer warnings
-dialyzer({nowarn_function, [handle_request/3, send_response/3, send_error/3]}).

%% @doc Handle an incoming LLM RPC request
-spec handle_request(binary(), map(), binary()) -> ok.
handle_request(RequestId, Payload, _AgentIdentity) ->
    logger:info("[handle_llm_rpc] Processing request: ~s", [RequestId]),

    %% Report request started (for status tracking)
    ModelName = maps:get(<<"model">>, Payload, <<>>),
    llm_status_heartbeat:report_request(ModelName),

    %% Extract request details
    Action = maps:get(<<"action">>, Payload, <<"chat">>),
    RequesterTopic = maps:get(<<"reply_to">>, Payload, undefined),

    Result = case Action of
        <<"chat">> ->
            handle_chat(Payload);
        <<"list_models">> ->
            handle_list_models();
        <<"health">> ->
            handle_health();
        _ ->
            {error, <<"unknown_action">>}
    end,

    %% Send response back to requester
    case RequesterTopic of
        undefined ->
            logger:warning("[handle_llm_rpc] No reply_to topic for request ~s", [RequestId]);
        _ ->
            case Result of
                {ok, Response} ->
                    send_response(RequesterTopic, RequestId, Response);
                {error, Reason} ->
                    send_error(RequesterTopic, RequestId, Reason)
            end
    end,

    %% Report completion (with token count if available)
    TokenCount = case Result of
        {ok, #{<<"eval_count">> := Tokens}} -> Tokens;
        _ -> 0
    end,
    llm_status_heartbeat:report_completion(ModelName, TokenCount),

    ok.

%% Handle chat request
handle_chat(Payload) ->
    Model = maps:get(<<"model">>, Payload, <<"llama3.2">>),
    Messages = maps:get(<<"messages">>, Payload, []),
    Stream = maps:get(<<"stream">>, Payload, false),

    case Stream of
        true ->
            %% Streaming not supported over mesh RPC (would need different protocol)
            %% Fall back to non-streaming
            handle_chat_sync(Model, Messages);
        false ->
            handle_chat_sync(Model, Messages)
    end.

handle_chat_sync(Model, Messages) ->
    Opts = #{model => Model},
    case llm_backend:chat(Messages, Opts) of
        {ok, Response} ->
            {ok, Response};
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

%% Handle list models request
handle_list_models() ->
    case llm_backend:list_models() of
        {ok, Models} ->
            {ok, #{<<"models">> => Models}};
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

%% Handle health check
handle_health() ->
    case llm_backend:health() of
        ok ->
            {ok, #{<<"status">> => <<"healthy">>}};
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

%% Send successful response back to requester
send_response(ReplyTopic, RequestId, Response) ->
    Payload = #{
        <<"request_id">> => RequestId,
        <<"status">> => <<"ok">>,
        <<"result">> => Response
    },
    case hecate_mesh_client:publish(ReplyTopic, Payload) of
        ok ->
            logger:debug("[handle_llm_rpc] Sent response for ~s", [RequestId]);
        {error, Reason} ->
            logger:warning("[handle_llm_rpc] Failed to send response: ~p", [Reason])
    end.

%% Send error response back to requester
send_error(ReplyTopic, RequestId, Reason) ->
    Payload = #{
        <<"request_id">> => RequestId,
        <<"status">> => <<"error">>,
        <<"error">> => Reason
    },
    case hecate_mesh_client:publish(ReplyTopic, Payload) of
        ok ->
            logger:debug("[handle_llm_rpc] Sent error for ~s", [RequestId]);
        {error, PublishError} ->
            logger:warning("[handle_llm_rpc] Failed to send error: ~p", [PublishError])
    end.

%% Format error for response
format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason, utf8);
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
