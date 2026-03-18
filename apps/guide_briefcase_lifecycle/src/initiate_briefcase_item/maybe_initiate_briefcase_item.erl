-module(maybe_initiate_briefcase_item).
-export([handle/1, handle_from_map/1, dispatch/1]).

-include_lib("evoq/include/evoq.hrl").

handle_from_map(Payload) ->
    case initiate_briefcase_item_v1:from_map(Payload) of
        {ok, Cmd} -> handle(Cmd);
        {error, _} = Err -> Err
    end.

handle(Cmd) ->
    case initiate_briefcase_item_v1:validate(Cmd) of
        {ok, _} ->
            Map = initiate_briefcase_item_v1:to_map(Cmd),
            Event = briefcase_item_initiated_v1:new(Map),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    Map = initiate_briefcase_item_v1:to_map(Cmd),
    ItemId = maps:get(item_id, Map),
    EvoqCmd = #evoq_command{
        command_type = initiate_briefcase_item,
        aggregate_type = briefcase_item_aggregate,
        aggregate_id = ItemId,
        payload = Map,
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
