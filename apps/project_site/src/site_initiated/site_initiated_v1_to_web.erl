%%% @doc Emitter: site_initiated_v1 -> web frontend via SSE.
%%%
%%% Broadcasts the full site state to connected web clients when the
%%% site is first initiated.
%%% @end
-module(site_initiated_v1_to_web).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"site_initiated_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, _Event, _Metadata, State) ->
    case project_site_store:get() of
        {ok, Site} ->
            hecate_web_events:broadcast(site_changed, Site#{
                reason => <<"site_initiated">>
            });
        _ ->
            ok
    end,
    {ok, State}.
