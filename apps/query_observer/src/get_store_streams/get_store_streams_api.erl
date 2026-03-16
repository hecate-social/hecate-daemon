%%% @doc GET /api/observer/stores/:store_id/streams — Stream list.
%%%
%%% Lists all streams in a store with their current version.
%%% @end
-module(get_store_streams_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/stores/:store_id/streams", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    StoreIdBin = cowboy_req:binding(store_id, Req0),
    StoreId = binary_to_existing_atom(StoreIdBin),
    case evoq_event_store:list_streams(StoreId) of
        {ok, StreamIds} ->
            Items = lists:map(fun(StreamId) ->
                Version = try evoq_event_store:version(StoreId, StreamId)
                          catch _:_ -> -1
                          end,
                #{
                    stream_id => StreamId,
                    version => Version,
                    event_count => Version + 1
                }
            end, StreamIds),
            hecate_api_utils:json_ok(#{items => Items, total => length(Items),
                                       store_id => StoreIdBin}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
