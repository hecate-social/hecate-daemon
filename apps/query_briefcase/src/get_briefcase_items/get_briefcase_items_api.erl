-module(get_briefcase_items_api).
-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/briefcase/items", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">>  -> handle_list(Req0, State);
        <<"POST">> -> handle_create(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0, State)
    end.

handle_list(Req0, State) ->
    Qs = cowboy_req:parse_qs(Req0),
    Filters = build_filters(Qs),
    {ok, Items} = project_briefcase_store:list_items(Filters),
    hecate_api_utils:json_ok(#{items => Items, total => length(Items)}, Req0, State).

handle_create(Req0, State) ->
    {ok, Body, Req1} = hecate_api_utils:read_json_body(Req0),
    ItemId = generate_id(),
    Payload = Body#{
        <<"command_type">> => <<"initiate_briefcase_item">>,
        <<"item_id">> => ItemId
    },
    Cmd = #evoq_command{
        command_type = initiate_briefcase_item,
        aggregate_type = briefcase_item_aggregate,
        aggregate_id = ItemId,
        payload = Payload,
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    case evoq_dispatcher:dispatch(Cmd, dispatch_opts()) of
        {ok, _, _} ->
            hecate_api_utils:json_ok(#{item_id => ItemId}, Req1, State);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1, State)
    end.

build_filters(Qs) ->
    lists:foldl(fun
        ({<<"parent_id">>, V}, Acc) -> Acc#{parent_id => V};
        ({<<"kind">>, V}, Acc) -> Acc#{kind => V};
        ({<<"starred">>, <<"true">>}, Acc) -> Acc#{starred => true};
        ({<<"search">>, V}, Acc) -> Acc#{search => V};
        ({<<"file_type">>, V}, Acc) -> Acc#{file_type => V};
        (_, Acc) -> Acc
    end, #{}, Qs).

generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Hex = binary:encode_hex(crypto:strong_rand_bytes(2)),
    <<"item-", Ts/binary, "-", Hex/binary>>.

dispatch_opts() ->
    #{store_id => briefcase_store, adapter => reckon_evoq_adapter, consistency => eventual}.
