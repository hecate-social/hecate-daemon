%%% @doc Synchronous facade for cross-plugin Briefcase operations.
%%%
%%% Plugins call these functions to sync metadata (e.g., rename)
%%% with the Briefcase item index. Same BEAM VM, no HTTP overhead.
-module(briefcase_api).

-include_lib("evoq/include/evoq.hrl").

-export([rename_item/2, get_item/1]).

-spec rename_item(binary(), binary()) -> {ok, integer(), [map()]} | {error, term()}.
rename_item(ItemId, NewName) ->
    Cmd = #evoq_command{
        command_type = rename_briefcase_item,
        aggregate_type = briefcase_item_aggregate,
        aggregate_id = ItemId,
        payload = #{
            command_type => <<"rename_briefcase_item">>,
            item_id => ItemId,
            name => NewName
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(Cmd, dispatch_opts()).

-spec get_item(binary()) -> {ok, map()} | {error, not_found}.
get_item(ItemId) ->
    project_briefcase_store:get_item(ItemId).

dispatch_opts() ->
    #{store_id => briefcase_store, adapter => reckon_evoq_adapter, consistency => eventual}.
