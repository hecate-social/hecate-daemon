%%% @doc Evoq event handler: forwards `license_issued_v1` events to the
%%% buffered mesh emitter.
%%%
%%% This module is the evoq subscriber; the actual batching + timing +
%%% publishing lives in `licenses_issued_batch_emitter` (a plain
%%% gen_server). Cleanly separates "observer of the event stream" from
%%% "buffered publisher" so the publisher can manage its own timers
%%% without fighting evoq's handler lifecycle.
%%% @end
-module(license_issued_v1_to_batch).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"license_issued_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(<<"license_issued_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    licenses_issued_batch_emitter:buffer(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.
