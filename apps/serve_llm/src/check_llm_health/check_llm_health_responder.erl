%%% @doc Check LLM Health Responder
%%% Listens for health check requests on mesh, returns health status.
-module(check_llm_health_responder).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    subscription_ref :: reference() | undefined,
    agent_identity :: binary()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    AgentIdentity = get_agent_identity(),
    Topic = build_topic(AgentIdentity, <<"health">>),
    SubRef = subscribe(Topic),
    {ok, #state{subscription_ref = SubRef, agent_identity = AgentIdentity}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({mesh_message, _Topic, Payload}, State) ->
    spawn(fun() -> handle_request(Payload) end),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_ref = undefined}) -> ok;
terminate(_Reason, #state{subscription_ref = SubRef}) ->
    hecate_mesh_client:unsubscribe(SubRef),
    ok.

%% Internal

handle_request(Payload) ->
    RequestId = maps:get(<<"request_id">>, Payload, <<>>),
    ReplyTo = maps:get(<<"reply_to">>, Payload, undefined),

    Result = check_llm_health:check(),

    case ReplyTo of
        undefined -> ok;
        _ -> send_response(ReplyTo, RequestId, Result)
    end.

send_response(ReplyTo, RequestId, ok) ->
    Payload = #{<<"request_id">> => RequestId, <<"status">> => <<"ok">>, <<"healthy">> => true},
    hecate_mesh_client:publish(ReplyTo, Payload);
send_response(ReplyTo, RequestId, {error, Reason}) ->
    Payload = #{<<"request_id">> => RequestId, <<"status">> => <<"ok">>, <<"healthy">> => false, <<"error">> => format_error(Reason)},
    hecate_mesh_client:publish(ReplyTo, Payload).

subscribe(Topic) ->
    Callback = fun(Msg) -> self() ! {mesh_message, Topic, Msg} end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} -> SubRef;
        {error, _} -> undefined
    end.

build_topic(AgentIdentity, Action) ->
    AgentPath = case AgentIdentity of
        <<"mri:agent:", Rest/binary>> -> Rest;
        _ -> AgentIdentity
    end,
    SafePath = binary:replace(AgentPath, <<"/">>, <<".">>, [global]),
    <<"hecate.llm.", Action/binary, ".", SafePath/binary>>.

get_agent_identity() ->
    application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>).

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason, utf8);
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
