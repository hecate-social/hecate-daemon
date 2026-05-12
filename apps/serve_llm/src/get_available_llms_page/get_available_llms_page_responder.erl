%%% @doc List Available LLMs Responder
%%% Listens for list requests on mesh, returns available models.
-module(get_available_llms_page_responder).
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
    Topic = hecate_topics:app_hope(<<"llm">>, <<"list_models">>, 1),
    self() ! {try_subscribe, Topic},
    {ok, #state{subscription_ref = undefined, agent_identity = get_agent_identity()}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({try_subscribe, Topic}, #state{subscription_ref = undefined} = State) ->
    case subscribe(Topic) of
        undefined ->
            erlang:send_after(3000, self(), {try_subscribe, Topic}),
            {noreply, State};
        SubRef ->
            logger:info("[get_available_llms_page_responder] Subscribed to mesh topic"),
            {noreply, State#state{subscription_ref = SubRef}}
    end;
handle_info({try_subscribe, _Topic}, State) ->
    {noreply, State};
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

    Result = get_available_llms_page:list(),

    case ReplyTo of
        undefined -> ok;
        _ -> send_response(ReplyTo, RequestId, Result)
    end.

send_response(ReplyTo, RequestId, {ok, Models}) ->
    Payload = #{<<"request_id">> => RequestId, <<"status">> => <<"ok">>, <<"models">> => Models},
    hecate_mesh_client:publish(ReplyTo, Payload);
send_response(ReplyTo, RequestId, {error, Reason}) ->
    Payload = #{<<"request_id">> => RequestId, <<"status">> => <<"error">>, <<"error">> => format_error(Reason)},
    hecate_mesh_client:publish(ReplyTo, Payload).

subscribe(Topic) ->
    Callback = fun(Msg) -> self() ! {mesh_message, Topic, Msg} end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} -> SubRef;
        {error, _} -> undefined
    end.

get_agent_identity() ->
    hecate_identity:agent_id().

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason, utf8);
format_error(Reason) -> iolist_to_binary(io_lib:format("~p", [Reason])).
