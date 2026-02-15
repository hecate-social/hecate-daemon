%%% @doc Mesh listener: hecate.irc.channel.opened -> local open_channel command
%%%
%%% When a remote node announces a channel, dispatches open_channel_v1
%%% locally so the channel appears in the local read model.
%%% If the aggregate already exists (local creation), the command fails
%%% silently — idempotent by design.
%%% @end
-module(subscribe_to_mesh_channel_opened).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [init/1, terminate/2]}).

-record(state, {
    mesh_sub_ref :: reference() | undefined
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    SubRef = case hecate_mesh_client:subscribe(<<"hecate.irc.channel.opened">>, self()) of
        {ok, Ref} -> Ref;
        {error, _} -> undefined
    end,
    logger:info("[subscribe_to_mesh_channel_opened] Started"),
    {ok, #state{mesh_sub_ref = SubRef}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({mesh_fact, _Topic, Payload}, State) ->
    %% Convert mesh fact to local command — idempotent
    case open_channel_v1:from_map(Payload) of
        {ok, Cmd} ->
            case maybe_open_channel:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("[subscribe_to_mesh_channel_opened] Remote channel replicated: ~s",
                        [open_channel_v1:get_channel_id(Cmd)]);
                {error, _Reason} ->
                    %% Already exists locally or other expected error — ignore
                    ok
            end;
        {error, _} ->
            logger:warning("[subscribe_to_mesh_channel_opened] Invalid payload: ~p", [Payload])
    end,
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{mesh_sub_ref = undefined}) ->
    ok;
terminate(_Reason, #state{mesh_sub_ref = SubRef}) ->
    hecate_mesh_client:unsubscribe(SubRef),
    ok.
