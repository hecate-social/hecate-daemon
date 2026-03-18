-module(get_briefcase_item_by_id_api).
-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/briefcase/items/:item_id", ?MODULE, []}].

init(Req0, State) ->
    ItemId = cowboy_req:binding(item_id, Req0),
    case cowboy_req:method(Req0) of
        <<"GET">>    -> handle_get(ItemId, Req0, State);
        <<"PUT">>    -> handle_update(ItemId, Req0, State);
        <<"DELETE">> -> handle_archive(ItemId, Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0, State)
    end.

handle_get(ItemId, Req0, State) ->
    case project_briefcase_store:get_item(ItemId) of
        {ok, Item} -> hecate_api_utils:json_ok(Item, Req0, State);
        {error, not_found} -> hecate_api_utils:json_error(404, <<"not_found">>, Req0, State)
    end.

handle_update(ItemId, Req0, State) ->
    {ok, Body, Req1} = hecate_api_utils:read_json_body(Req0),
    Results = lists:filtermap(fun
        ({<<"name">>, Name}) when is_binary(Name) ->
            {true, dispatch_cmd(rename_briefcase_item, ItemId, #{<<"name">> => Name, <<"item_id">> => ItemId})};
        ({<<"parent_id">>, Pid}) ->
            {true, dispatch_cmd(move_briefcase_item, ItemId, #{<<"parent_id">> => Pid, <<"item_id">> => ItemId})};
        ({<<"starred">>, true}) ->
            {true, dispatch_cmd(star_briefcase_item, ItemId, #{<<"item_id">> => ItemId})};
        ({<<"starred">>, false}) ->
            {true, dispatch_cmd(unstar_briefcase_item, ItemId, #{<<"item_id">> => ItemId})};
        (_) -> false
    end, maps:to_list(Body)),
    case lists:filter(fun({error, _}) -> true; (_) -> false end, Results) of
        [{error, Reason} | _] -> hecate_api_utils:json_error(400, Reason, Req1, State);
        [] -> hecate_api_utils:json_ok(#{item_id => ItemId}, Req1, State)
    end.

handle_archive(ItemId, Req0, State) ->
    case dispatch_cmd(archive_briefcase_item, ItemId, #{<<"item_id">> => ItemId}) of
        {ok, _, _} -> hecate_api_utils:json_ok(#{item_id => ItemId}, Req0, State);
        {error, Reason} -> hecate_api_utils:json_error(400, Reason, Req0, State)
    end.

dispatch_cmd(CmdType, ItemId, Payload) ->
    CmdTypeBin = atom_to_binary(CmdType),
    Cmd = #evoq_command{
        command_type = CmdType,
        aggregate_type = briefcase_item_aggregate,
        aggregate_id = ItemId,
        payload = Payload#{<<"command_type">> => CmdTypeBin},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(Cmd, #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
