%%% @doc GET /api/observer/stores — Event store overview.
%%%
%%% Per store: store_id, running, has_events, stream_count,
%%% associated ETS projection table and size.
%%% @end
-module(get_stores_inspector_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/stores", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Stores = discover_stores(),
    Items = [format_store(S) || S <- Stores],
    hecate_api_utils:json_ok(#{items => Items, total => length(Items)}, Req0).

discover_stores() ->
    %% Try reckon_gater_api:list_stores/0 first (richer metadata)
    case catch reckon_gater_api:list_stores() of
        {ok, StoreList} when is_list(StoreList) ->
            StoreList;
        _ ->
            %% Fallback: get store IDs from reckon_db_sup
            case catch reckon_db_sup:which_stores() of
                Stores when is_list(Stores) ->
                    [#{store_id => S} || S <- Stores];
                _ -> []
            end
    end.

format_store(#{store_id := StoreId} = StoreInfo) ->
    StoreAtom = to_atom(StoreId),
    HasEvents = try evoq_event_store:has_events(StoreAtom)
                catch _:_ -> false
                end,
    StreamCount = try
        case evoq_event_store:list_streams(StoreAtom) of
            {ok, Streams} -> length(Streams);
            _ -> 0
        end
    catch _:_ -> 0
    end,
    EtsInfo = find_projection_ets(StoreAtom),
    Base = #{
        store_id => to_binary(StoreId),
        running => is_store_running(StoreAtom),
        has_events => HasEvents,
        stream_count => StreamCount,
        ets_tables => EtsInfo
    },
    %% Include any extra metadata from gater
    Extra = maps:without([store_id], StoreInfo),
    maps:merge(format_extra(Extra), Base);
format_store(Other) ->
    #{
        store_id => to_binary(Other),
        running => false,
        has_events => false,
        stream_count => 0,
        ets_tables => []
    }.

is_store_running(StoreAtom) ->
    case whereis(StoreAtom) of
        undefined -> false;
        Pid -> is_process_alive(Pid)
    end.

%% Find ETS tables likely associated with this store domain
find_projection_ets(StoreAtom) ->
    %% Convention: store is {domain}_store, ETS tables are {domain} or {domain}_*
    StoreStr = atom_to_list(StoreAtom),
    Domain = case string:split(StoreStr, "_store", trailing) of
        [D, ""] -> D;
        _ -> StoreStr
    end,
    AllTables = ets:all(),
    lists:filtermap(fun(Tab) ->
        try
            case ets:info(Tab, named_table) of
                true ->
                    TabStr = atom_to_list(Tab),
                    case string:find(TabStr, Domain) of
                        nomatch -> false;
                        _ ->
                            {true, #{
                                name => atom_to_binary(Tab),
                                size => ets:info(Tab, size),
                                memory_bytes => ets:info(Tab, memory) * erlang:system_info(wordsize)
                            }}
                    end;
                _ -> false
            end
        catch _:_ -> false
        end
    end, AllTables).

to_atom(A) when is_atom(A) -> A;
to_atom(B) when is_binary(B) -> binary_to_existing_atom(B);
to_atom(L) when is_list(L) -> list_to_existing_atom(L).

to_binary(A) when is_atom(A) -> atom_to_binary(A);
to_binary(B) when is_binary(B) -> B;
to_binary(Other) -> iolist_to_binary(io_lib:format("~p", [Other])).

format_extra(Map) when map_size(Map) =:= 0 -> #{};
format_extra(Map) ->
    maps:fold(fun(K, V, Acc) ->
        Acc#{to_binary(K) => to_binary(V)}
    end, #{}, Map).
