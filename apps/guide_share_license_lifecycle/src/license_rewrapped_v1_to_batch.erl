%%% @doc Evoq handler: forwards `license_rewrapped_v1` events to the
%%% buffered mesh emitter (`licenses_rewrapped_batch_emitter`).
%%%
%%% Same separation-of-concerns pattern as
%%% `license_issued_v1_to_batch` — the evoq subscription lives here,
%%% the buffering + timing + publishing lives in the gen_server.
%%% @end
-module(license_rewrapped_v1_to_batch).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"license_rewrapped_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(<<"license_rewrapped_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    licenses_rewrapped_batch_emitter:buffer(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.
