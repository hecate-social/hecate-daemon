%%% @doc Emitter: plugin_activated_v1 -> pg (internal pub/sub)
-module(plugin_activated_v1_to_pg).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

-define(PG_GROUP, {plugin_activated_v1, node()}).

interested_in() -> [<<"plugin_activated_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Members = pg:get_members(hecate, ?PG_GROUP),
    Msg = {plugin_activated_v1, Event},
    lists:foreach(fun(Pid) -> Pid ! Msg end, Members),
    {ok, State}.
