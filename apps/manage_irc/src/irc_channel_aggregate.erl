%%% @doc IRC channel aggregate — lifecycle for chat channels.
%%%
%%% Stream: irc-channel-{channel_id}
%%% Store: dev_studio_store
%%%
%%% Lifecycle:
%%%   1. open_channel (birth event)
%%%   2. close_channel (walking skeleton archive)
%%% @end
-module(irc_channel_aggregate).

-behaviour(evoq_aggregate).

-include("irc_channel_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-record(irc_channel_state, {
    channel_id  :: binary() | undefined,
    name        :: binary() | undefined,
    topic       :: binary() | undefined,
    opened_by   :: binary() | undefined,
    status = 0  :: non_neg_integer(),
    opened_at   :: non_neg_integer() | undefined
}).

-type state() :: #irc_channel_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?IRC_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #irc_channel_state{}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) — State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only open allowed
execute(#irc_channel_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"open_channel">> -> execute_open_channel(Payload);
        _ -> {error, channel_not_opened}
    end;

%% Archived — nothing allowed
execute(#irc_channel_state{status = S}, _Payload) when S band ?IRC_ARCHIVED =/= 0 ->
    {error, channel_closed};

%% Opened — route by command type
execute(#irc_channel_state{status = S} = _State, Payload) when S band ?IRC_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"close_channel">> -> execute_close_channel(Payload);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_open_channel(Payload) ->
    {ok, Cmd} = open_channel_v1:from_map(Payload),
    convert_events(maybe_open_channel:handle(Cmd), fun channel_opened_v1:to_map/1).

execute_close_channel(Payload) ->
    {ok, Cmd} = close_channel_v1:from_map(Payload),
    convert_events(maybe_close_channel:handle(Cmd), fun channel_closed_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) — State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"channel_opened_v1">>} = E, S) -> apply_opened(E, S);
apply_event(#{event_type := <<"channel_opened_v1">>} = E, S)      -> apply_opened(E, S);
apply_event(#{<<"event_type">> := <<"channel_closed_v1">>} = _E, S) -> apply_closed(S);
apply_event(#{event_type := <<"channel_closed_v1">>} = _E, S)       -> apply_closed(S);
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_opened(E, State) ->
    State#irc_channel_state{
        channel_id = get_value(channel_id, E),
        name = get_value(name, E),
        topic = get_value(topic, E),
        opened_by = get_value(opened_by, E),
        status = evoq_bit_flags:set(0, ?IRC_INITIATED),
        opened_at = get_value(opened_at, E)
    }.

apply_closed(#irc_channel_state{status = Status} = State) ->
    State#irc_channel_state{status = evoq_bit_flags:set(Status, ?IRC_ARCHIVED)}.

%% --- Internal ---

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
