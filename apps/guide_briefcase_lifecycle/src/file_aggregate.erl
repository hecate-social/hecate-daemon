%%% @doc File aggregate.
%%%
%%% Stream: file-{file_id}
%%% Store: briefcase_store
%%%
%%% Two birth events:
%%%   - file_registered (plugin-created, no blob)
%%%   - file_imported (user import, has blob)
%%%
%%% Lifecycle after birth:
%%%   rename_file, move_file, star_file, unstar_file, archive_file
%%% @end
-module(file_aggregate).

-behaviour(evoq_aggregate).

-include("file_status.hrl").
-include("file_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0]).
-export([flag_map/0]).

-type state() :: file_state:state().
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> file_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?FILE_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, file_state:new(AggregateId)}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only register_file or import_file allowed
execute(#file_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"register_file">> -> execute_register_file(Payload);
        <<"import_file">>   -> execute_import_file(Payload);
        _ -> {error, file_not_initiated}
    end;

%% Archived — reject everything
execute(#file_state{status = S}, _Payload) when S band ?FILE_ARCHIVED =/= 0 ->
    {error, file_archived};

%% Initiated — route by command type
execute(#file_state{status = S, starred = Starred}, Payload)
  when S band ?FILE_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"register_file">> -> {error, file_already_initiated};
        <<"import_file">>   -> {error, file_already_initiated};
        <<"rename_file">>   -> execute_rename_file(Payload);
        <<"move_file">>     -> execute_move_file(Payload);
        <<"star_file">>     ->
            case Starred of
                true -> {error, file_already_starred};
                _    -> execute_star_file(Payload)
            end;
        <<"unstar_file">>   ->
            case Starred of
                false -> {error, file_not_starred};
                _     -> execute_unstar_file(Payload)
            end;
        <<"archive_file">>  -> execute_archive_file(Payload);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_register_file(Payload) ->
    {ok, Cmd} = register_file_v1:from_map(Payload),
    convert_events(maybe_register_file:handle(Cmd), fun file_registered_v1:to_map/1).

execute_import_file(Payload) ->
    {ok, Cmd} = import_file_v1:from_map(Payload),
    convert_events(maybe_import_file:handle(Cmd), fun file_imported_v1:to_map/1).

execute_rename_file(Payload) ->
    {ok, Cmd} = rename_file_v1:from_map(Payload),
    convert_events(maybe_rename_file:handle(Cmd), fun file_renamed_v1:to_map/1).

execute_move_file(Payload) ->
    {ok, Cmd} = move_file_v1:from_map(Payload),
    convert_events(maybe_move_file:handle(Cmd), fun file_moved_v1:to_map/1).

execute_star_file(Payload) ->
    {ok, Cmd} = star_file_v1:from_map(Payload),
    convert_events(maybe_star_file:handle(Cmd), fun file_starred_v1:to_map/1).

execute_unstar_file(Payload) ->
    {ok, Cmd} = unstar_file_v1:from_map(Payload),
    convert_events(maybe_unstar_file:handle(Cmd), fun file_unstarred_v1:to_map/1).

execute_archive_file(Payload) ->
    {ok, Cmd} = archive_file_v1:from_map(Payload),
    convert_events(maybe_archive_file:handle(Cmd), fun file_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    file_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
