%%% @doc Folder aggregate.
%%%
%%% Stream: folder-{folder_id}
%%% Store: briefcase_store
%%%
%%% Lifecycle:
%%%   1. create_folder (birth event)
%%%   2. rename_folder
%%%   3. move_folder
%%%   4. archive_folder
%%% @end
-module(folder_aggregate).

-behaviour(evoq_aggregate).

-include("folder_status.hrl").
-include("folder_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0]).
-export([flag_map/0]).

-type state() :: folder_state:state().
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> folder_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?FOLDER_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, folder_state:new(AggregateId)}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only create_folder allowed
execute(#folder_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"create_folder">> -> execute_create_folder(Payload);
        _ -> {error, folder_not_initiated}
    end;

%% Archived — reject everything
execute(#folder_state{status = S}, _Payload) when S band ?FOLDER_ARCHIVED =/= 0 ->
    {error, folder_archived};

%% Initiated — route by command type
execute(#folder_state{status = S}, Payload) when S band ?FOLDER_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"create_folder">>  -> {error, folder_already_initiated};
        <<"rename_folder">>  -> execute_rename_folder(Payload);
        <<"move_folder">>    -> execute_move_folder(Payload);
        <<"archive_folder">> -> execute_archive_folder(Payload);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_create_folder(Payload) ->
    {ok, Cmd} = create_folder_v1:from_map(Payload),
    convert_events(maybe_create_folder:handle(Cmd), fun folder_initiated_v1:to_map/1).

execute_rename_folder(Payload) ->
    {ok, Cmd} = rename_folder_v1:from_map(Payload),
    convert_events(maybe_rename_folder:handle(Cmd), fun folder_renamed_v1:to_map/1).

execute_move_folder(Payload) ->
    {ok, Cmd} = move_folder_v1:from_map(Payload),
    convert_events(maybe_move_folder:handle(Cmd), fun folder_moved_v1:to_map/1).

execute_archive_folder(Payload) ->
    {ok, Cmd} = archive_folder_v1:from_map(Payload),
    convert_events(maybe_archive_folder:handle(Cmd), fun folder_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    folder_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
