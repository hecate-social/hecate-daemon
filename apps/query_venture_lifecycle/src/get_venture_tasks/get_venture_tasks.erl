%%% @doc Query: generate task list based on venture status bit flags.
%%% Returns what's done, what's in progress, and what's next.
-module(get_venture_tasks).

-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").

-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(VentureId) ->
    Sql = "SELECT status FROM ventures WHERE venture_id = ?1",
    case query_venture_lifecycle_store:query(Sql, [VentureId]) of
        {ok, [[Status]]} ->
            Tasks = build_tasks(Status),
            {ok, #{
                venture_id => VentureId,
                status => Status,
                tasks => Tasks
            }};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

build_tasks(Status) ->
    lists:filtermap(fun(TaskDef) -> maybe_task(Status, TaskDef) end, task_definitions()).

task_definitions() ->
    [
        {?VL_INITIATED, <<"Initiate venture">>, initiate},
        {?VL_SUBMITTED, <<"Refine and submit vision">>, submit_vision},
        {?VL_DISCOVERING, <<"Start discovery">>, start_discovery},
        {?VL_DISCOVERY_COMPLETED, <<"Discover divisions">>, discover_divisions}
    ].

maybe_task(Status, {?VL_INITIATED, Label, _Action}) ->
    case Status band ?VL_INITIATED of
        0 -> {true, #{task => Label, status => <<"pending">>}};
        _ -> {true, #{task => Label, status => <<"done">>}}
    end;
maybe_task(Status, {?VL_SUBMITTED, Label, _Action}) ->
    case Status band ?VL_INITIATED of
        0 -> false;
        _ ->
            case Status band ?VL_SUBMITTED of
                0 -> {true, #{task => Label, status => <<"in_progress">>}};
                _ -> {true, #{task => Label, status => <<"done">>}}
            end
    end;
maybe_task(Status, {?VL_DISCOVERING, Label, _Action}) ->
    case Status band ?VL_SUBMITTED of
        0 -> false;
        _ ->
            case Status band ?VL_DISCOVERING of
                0 ->
                    case Status band ?VL_DISCOVERY_COMPLETED of
                        0 -> {true, #{task => Label, status => <<"pending">>}};
                        _ -> {true, #{task => Label, status => <<"done">>}}
                    end;
                _ -> {true, #{task => Label, status => <<"done">>}}
            end
    end;
maybe_task(Status, {?VL_DISCOVERY_COMPLETED, Label, _Action}) ->
    case Status band ?VL_DISCOVERING of
        0 ->
            case Status band ?VL_DISCOVERY_COMPLETED of
                0 -> false;
                _ -> {true, #{task => Label, status => <<"done">>}}
            end;
        _ -> {true, #{task => Label, status => <<"in_progress">>}}
    end.
