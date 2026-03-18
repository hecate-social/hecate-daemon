-module(briefcase_item_aggregate).
-behaviour(evoq_aggregate).

-include("briefcase_item_status.hrl").
-include("briefcase_item_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, flag_map/0]).

state_module() -> briefcase_item_state.
flag_map() -> ?ITEM_FLAG_MAP.

init(AggregateId) ->
    {ok, briefcase_item_state:new(AggregateId)}.

%% Fresh — only initiate allowed
execute(#briefcase_item_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_briefcase_item">> -> do_execute(initiate, Payload);
        _ -> {error, item_not_initiated}
    end;

%% Archived — nothing allowed
execute(#briefcase_item_state{status = S}, _Payload) when S band ?ITEM_ARCHIVED =/= 0 ->
    {error, item_archived};

%% Initiated — route by command type
execute(#briefcase_item_state{} = State, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_briefcase_item">>  -> {error, item_already_initiated};
        <<"rename_briefcase_item">>    -> do_execute(rename, Payload);
        <<"move_briefcase_item">>      -> do_execute(move, Payload);
        <<"star_briefcase_item">>      -> do_execute(star, Payload, State);
        <<"unstar_briefcase_item">>    -> do_execute(unstar, Payload, State);
        <<"archive_briefcase_item">>   -> do_execute(archive, Payload);
        _ -> {error, unknown_command}
    end.

apply(State, Event) ->
    briefcase_item_state:apply_event(State, Event).

%% Internal

do_execute(initiate, Payload) ->
    maybe_initiate_briefcase_item:handle_from_map(Payload);
do_execute(rename, Payload) ->
    maybe_rename_briefcase_item:handle_from_map(Payload);
do_execute(move, Payload) ->
    maybe_move_briefcase_item:handle_from_map(Payload);
do_execute(archive, Payload) ->
    maybe_archive_briefcase_item:handle_from_map(Payload).

do_execute(star, _Payload, #briefcase_item_state{starred = true}) ->
    {error, already_starred};
do_execute(star, Payload, _State) ->
    maybe_star_briefcase_item:handle_from_map(Payload);
do_execute(unstar, _Payload, #briefcase_item_state{starred = false}) ->
    {error, not_starred};
do_execute(unstar, Payload, _State) ->
    maybe_unstar_briefcase_item:handle_from_map(Payload).

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{<<"command_type">> := T}) when is_binary(T) -> T;
get_command_type(_) -> undefined.
