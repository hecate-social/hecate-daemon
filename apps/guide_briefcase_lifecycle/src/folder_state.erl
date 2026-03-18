%%% @doc Folder aggregate state module.
%%%
%%% Owns the folder_state record shape, initial state creation,
%%% event folding (apply), and serialization.
%%% @end
-module(folder_state).

-behaviour(evoq_state).

-include("folder_status.hrl").
-include("folder_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #folder_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #folder_state{status = 0}.

-spec apply_event(state(), map()) -> state().

apply_event(S, #{event_type := <<"folder_initiated_v1">>} = E) -> apply_initiated(E, S);
apply_event(S, #{event_type := <<"folder_renamed_v1">>} = E)   -> apply_renamed(E, S);
apply_event(S, #{event_type := <<"folder_moved_v1">>} = E)     -> apply_moved(E, S);
apply_event(S, #{event_type := <<"folder_archived_v1">>} = E)  -> apply_archived(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#folder_state{} = S) ->
    Base = #{
        folder_id  => S#folder_state.folder_id,
        name       => S#folder_state.name,
        status     => S#folder_state.status,
        created_at => S#folder_state.created_at,
        updated_at => S#folder_state.updated_at
    },
    maybe_put(icon, S#folder_state.icon,
    maybe_put(parent_id, S#folder_state.parent_id, Base)).

%% --- Apply helpers ---

apply_initiated(E, _State) ->
    Now = get_value(created_at, E, erlang:system_time(millisecond)),
    #folder_state{
        folder_id  = get_value(folder_id, E),
        name       = get_value(name, E),
        parent_id  = get_value(parent_id, E),
        icon       = get_value(icon, E),
        status     = ?FOLDER_INITIATED,
        created_at = Now,
        updated_at = Now
    }.

apply_renamed(E, #folder_state{status = Status} = State) ->
    Now = get_value(renamed_at, E, erlang:system_time(millisecond)),
    State#folder_state{
        name       = get_value(name, E),
        status     = evoq_bit_flags:set(Status, ?FOLDER_RENAMED),
        updated_at = Now
    }.

apply_moved(E, #folder_state{status = Status} = State) ->
    Now = get_value(moved_at, E, erlang:system_time(millisecond)),
    State#folder_state{
        parent_id  = get_value(parent_id, E),
        status     = evoq_bit_flags:set(Status, ?FOLDER_MOVED),
        updated_at = Now
    }.

apply_archived(E, #folder_state{status = Status} = State) ->
    Now = get_value(archived_at, E, erlang:system_time(millisecond)),
    State#folder_state{
        status     = evoq_bit_flags:set(Status, ?FOLDER_ARCHIVED),
        updated_at = Now
    }.

%% --- Internal ---

get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> undefined;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.

%% @private Only add key to map if value is not undefined/null.
maybe_put(_Key, undefined, Map) -> Map;
maybe_put(_Key, null, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.
