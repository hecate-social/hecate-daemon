%%% @doc Setup aggregate
%%% Maintains Venture setup state and applies events.
%%% Handles the inception process: setup, vision refinement, submission, archival.
-module(setup_aggregate).
-behaviour(evoq_aggregate).

-include("venture_status.hrl").

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Aliases for testing
-export([initial_state/0, apply_event/2]).

%% Bit flag descriptions for status display
-export([flag_map/0]).

-define(SETUP,     ?VENTURE_SETUP).
-define(REFINED,   ?VENTURE_VISION_REFINED).
-define(SUBMITTED, ?VENTURE_SUBMITTED).
-define(ARCHIVED,  ?VENTURE_ARCHIVED).

-record(setup_state, {
    venture_id   :: binary() | undefined,
    name         :: binary() | undefined,
    brief        :: binary() | undefined,
    status       :: non_neg_integer(),
    repos        :: [binary()],
    skills       :: [binary()],
    context_map  :: map(),
    initiated_at :: non_neg_integer() | undefined,
    initiated_by :: binary() | undefined
}).

-type state() :: #setup_state{}.
-export_type([state/0]).

%% @doc Flag map for status display via evoq_bit_flags:to_string/2
-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?VENTURE_FLAG_MAP.

%% @doc Behaviour callback: init/1
-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #setup_state{
        venture_id = undefined,
        name = undefined,
        brief = undefined,
        status = 0,
        repos = [],
        skills = [],
        context_map = #{},
        initiated_at = undefined,
        initiated_by = undefined
    }.

%% @doc Execute command against aggregate state
%% NOTE: evoq calls execute(State, Payload) - state first, then payload!
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, Payload) ->
    case get_command_type(Payload) of
        <<"setup_venture">> -> execute_setup_venture(Payload, State);
        <<"refine_vision">> -> execute_refine_vision(Payload, State);
        <<"submit_vision">> -> execute_submit_vision(Payload, State);
        <<"archive_venture">> -> execute_archive_venture(Payload, State);
        _ -> {error, unknown_command}
    end.

%% Extract command_type from atom or binary keyed map
get_command_type(#{command_type := V}) -> V;
get_command_type(#{<<"command_type">> := V}) -> V;
get_command_type(_) -> undefined.

execute_setup_venture(Payload, #setup_state{status = 0}) ->
    {ok, Cmd} = setup_venture_v1:from_map(Payload),
    convert_events(maybe_setup_venture:handle(Cmd), fun venture_setup_v1:to_map/1);
execute_setup_venture(_Payload, _State) ->
    {error, venture_already_setup}.

execute_refine_vision(_Payload, #setup_state{venture_id = undefined}) ->
    {error, venture_not_found};
execute_refine_vision(_Payload, #setup_state{status = Status}) when Status band ?ARCHIVED =/= 0 ->
    {error, venture_archived};
execute_refine_vision(_Payload, #setup_state{status = Status}) when Status band ?SETUP =:= 0 ->
    {error, venture_not_setup};
execute_refine_vision(_Payload, #setup_state{status = Status}) when Status band ?SUBMITTED =/= 0 ->
    {error, vision_already_submitted};
execute_refine_vision(Payload, _State) ->
    {ok, Cmd} = refine_vision_v1:from_map(Payload),
    convert_events(maybe_refine_vision:handle(Cmd), fun venture_vision_refined_v1:to_map/1).

execute_submit_vision(_Payload, #setup_state{venture_id = undefined}) ->
    {error, venture_not_found};
execute_submit_vision(_Payload, #setup_state{status = Status}) when Status band ?ARCHIVED =/= 0 ->
    {error, venture_archived};
execute_submit_vision(_Payload, #setup_state{status = Status}) when Status band ?SETUP =:= 0 ->
    {error, venture_not_setup};
execute_submit_vision(_Payload, #setup_state{status = Status}) when Status band ?SUBMITTED =/= 0 ->
    {error, vision_already_submitted};
execute_submit_vision(Payload, _State) ->
    {ok, Cmd} = submit_vision_v1:from_map(Payload),
    convert_events(maybe_submit_vision:handle(Cmd), fun venture_vision_submitted_v1:to_map/1).

execute_archive_venture(_Payload, #setup_state{venture_id = undefined}) ->
    {error, venture_not_found};
execute_archive_venture(_Payload, #setup_state{status = Status}) when Status band ?ARCHIVED =/= 0 ->
    {error, venture_already_archived};
execute_archive_venture(_Payload, #setup_state{status = Status}) when Status band ?SETUP =:= 0 ->
    {error, venture_not_setup};
execute_archive_venture(Payload, _State) ->
    {ok, Cmd} = archive_venture_v1:from_map(Payload),
    convert_events(maybe_archive_venture:handle(Cmd), fun venture_archived_v1:to_map/1).

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

%% @doc Behaviour callback: apply/2
%% NOTE: evoq calls apply(State, Event) - state first, then event!
-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

%% @doc Apply event to state (event sourcing)
-spec apply_event(map(), state()) -> state().
apply_event(#{<<"event_type">> := <<"venture_setup_v1">>} = E, State) ->
    apply_venture_setup(E, State);
apply_event(#{event_type := <<"venture_setup_v1">>} = E, State) ->
    apply_venture_setup(E, State);
apply_event(#{<<"event_type">> := <<"venture_vision_refined_v1">>} = E, State) ->
    apply_venture_vision_refined(E, State);
apply_event(#{event_type := <<"venture_vision_refined_v1">>} = E, State) ->
    apply_venture_vision_refined(E, State);
apply_event(#{<<"event_type">> := <<"venture_vision_submitted_v1">>} = _E, State) ->
    apply_venture_vision_submitted(State);
apply_event(#{event_type := <<"venture_vision_submitted_v1">>} = _E, State) ->
    apply_venture_vision_submitted(State);
apply_event(#{<<"event_type">> := <<"venture_archived_v1">>} = _E, State) ->
    apply_venture_archived(State);
apply_event(#{event_type := <<"venture_archived_v1">>} = _E, State) ->
    apply_venture_archived(State);
apply_event(_E, State) ->
    State.

apply_venture_setup(E, State) ->
    State#setup_state{
        venture_id = get_value(venture_id, E),
        name = get_value(name, E),
        brief = get_value(brief, E),
        status = evoq_bit_flags:set(0, ?SETUP),
        repos = get_value(repos, E, []),
        skills = get_value(skills, E, []),
        context_map = get_value(context_map, E, #{}),
        initiated_at = get_value(initiated_at, E),
        initiated_by = get_value(initiated_by, E)
    }.

apply_venture_vision_refined(E, State) ->
    S1 = case get_value(brief, E) of
        undefined -> State;
        Brief -> State#setup_state{brief = Brief}
    end,
    S2 = case get_value(repos, E) of
        undefined -> S1;
        Repos -> S1#setup_state{repos = Repos}
    end,
    S3 = case get_value(skills, E) of
        undefined -> S2;
        Skills -> S2#setup_state{skills = Skills}
    end,
    S4 = case get_value(context_map, E) of
        undefined -> S3;
        ContextMap -> S3#setup_state{context_map = ContextMap}
    end,
    S4#setup_state{
        status = evoq_bit_flags:set(S4#setup_state.status, ?REFINED)
    }.

apply_venture_vision_submitted(#setup_state{status = Status} = State) ->
    State#setup_state{
        status = evoq_bit_flags:set(Status, ?SUBMITTED)
    }.

apply_venture_archived(#setup_state{status = Status} = State) ->
    State#setup_state{
        status = evoq_bit_flags:set(Status, ?ARCHIVED)
    }.

%% Helper to get value from map with atom or binary keys
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
