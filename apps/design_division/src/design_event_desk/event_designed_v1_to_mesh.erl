-module(event_designed_v1_to_mesh).
-behaviour(gen_server).
-export([start_link/0, emit/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(TOPIC, <<"hecate.design.event_designed">>).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

emit(Event) ->
    gen_server:cast(?MODULE, {emit, Event}).

init([]) -> {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.

handle_cast({emit, EventData}, State) ->
    DivisionId = maps:get(<<"division_id">>, EventData, maps:get(division_id, EventData, <<"unknown">>)),
    EventName = maps:get(<<"event_name">>, EventData, maps:get(event_name, EventData, <<"unknown">>)),
    case hecate_mesh_client:publish(?TOPIC, EventData) of
        ok ->
            logger:info("[event_designed_v1_to_mesh] emitted for division ~s event ~s", [DivisionId, EventName]);
        {error, Reason} ->
            logger:warning("[event_designed_v1_to_mesh] failed for division ~s event ~s: ~p", [DivisionId, EventName, Reason])
    end,
    {noreply, State}.

handle_info(_Info, State) -> {noreply, State}.
