%%% @doc File aggregate state module.
%%%
%%% Owns the file_state record shape, initial state creation,
%%% event folding (apply), and serialization.
%%%
%%% Two birth events: file_registered (plugin-created) and file_imported (user import with blob).
%%% Both set FILE_INITIATED. file_imported additionally sets FILE_IMPORTED.
%%% @end
-module(file_state).

-behaviour(evoq_state).

-include("file_status.hrl").
-include("file_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #file_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #file_state{status = 0, size = 0, starred = false}.

-spec apply_event(state(), map()) -> state().

apply_event(S, #{event_type := <<"file_registered_v1">>} = E)  -> apply_registered(E, S);
apply_event(S, #{event_type := <<"file_imported_v1">>} = E)    -> apply_imported(E, S);
apply_event(S, #{event_type := <<"file_renamed_v1">>} = E)     -> apply_renamed(E, S);
apply_event(S, #{event_type := <<"file_moved_v1">>} = E)       -> apply_moved(E, S);
apply_event(S, #{event_type := <<"file_starred_v1">>} = E)     -> apply_starred(E, S);
apply_event(S, #{event_type := <<"file_unstarred_v1">>} = E)   -> apply_unstarred(E, S);
apply_event(S, #{event_type := <<"file_archived_v1">>} = E)    -> apply_archived(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#file_state{} = S) ->
    Base = #{
        file_id    => S#file_state.file_id,
        name       => S#file_state.name,
        file_type  => S#file_state.file_type,
        size       => S#file_state.size,
        starred    => S#file_state.starred,
        status     => S#file_state.status,
        created_at => S#file_state.created_at,
        updated_at => S#file_state.updated_at
    },
    maybe_put(mime_type, S#file_state.mime_type,
    maybe_put(blob_id, S#file_state.blob_id,
    maybe_put(icon, S#file_state.icon,
    maybe_put(plugin, S#file_state.plugin,
    maybe_put(folder_id, S#file_state.folder_id, Base))))).

%% --- Apply helpers ---

apply_registered(E, _State) ->
    Now = get_value(created_at, E, erlang:system_time(millisecond)),
    #file_state{
        file_id    = get_value(file_id, E),
        name       = get_value(name, E),
        folder_id  = get_value(folder_id, E),
        file_type  = get_value(file_type, E),
        plugin     = get_value(plugin, E),
        icon       = get_value(icon, E),
        blob_id    = undefined,
        size       = 0,
        mime_type  = undefined,
        starred    = false,
        status     = ?FILE_INITIATED,
        created_at = Now,
        updated_at = Now
    }.

apply_imported(E, _State) ->
    Now = get_value(created_at, E, erlang:system_time(millisecond)),
    #file_state{
        file_id    = get_value(file_id, E),
        name       = get_value(name, E),
        folder_id  = get_value(folder_id, E),
        file_type  = get_value(file_type, E),
        plugin     = get_value(plugin, E),
        icon       = get_value(icon, E),
        blob_id    = get_value(blob_id, E),
        size       = get_value(size, E, 0),
        mime_type  = get_value(mime_type, E),
        starred    = false,
        status     = evoq_bit_flags:set(?FILE_INITIATED, ?FILE_IMPORTED),
        created_at = Now,
        updated_at = Now
    }.

apply_renamed(E, #file_state{status = Status} = State) ->
    Now = get_value(renamed_at, E, erlang:system_time(millisecond)),
    State#file_state{
        name       = get_value(name, E),
        status     = evoq_bit_flags:set(Status, ?FILE_RENAMED),
        updated_at = Now
    }.

apply_moved(E, #file_state{status = Status} = State) ->
    Now = get_value(moved_at, E, erlang:system_time(millisecond)),
    State#file_state{
        folder_id  = get_value(folder_id, E),
        status     = evoq_bit_flags:set(Status, ?FILE_MOVED),
        updated_at = Now
    }.

apply_starred(E, #file_state{status = Status} = State) ->
    Now = get_value(starred_at, E, erlang:system_time(millisecond)),
    State#file_state{
        starred    = true,
        status     = evoq_bit_flags:set(Status, ?FILE_STARRED),
        updated_at = Now
    }.

apply_unstarred(E, #file_state{status = Status} = State) ->
    Now = get_value(unstarred_at, E, erlang:system_time(millisecond)),
    State#file_state{
        starred    = false,
        status     = evoq_bit_flags:unset(Status, ?FILE_STARRED),
        updated_at = Now
    }.

apply_archived(E, #file_state{status = Status} = State) ->
    Now = get_value(archived_at, E, erlang:system_time(millisecond)),
    State#file_state{
        status     = evoq_bit_flags:set(Status, ?FILE_ARCHIVED),
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
