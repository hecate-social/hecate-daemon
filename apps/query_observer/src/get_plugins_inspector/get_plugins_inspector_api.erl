%%% @doc GET /api/observer/plugins — Plugin inspector.
%%%
%%% Returns loaded plugins with health, callback module, store info.
%%% @end
-module(get_plugins_inspector_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/plugins", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Plugins = try hecate_plugin_loader:loaded_plugins()
              catch _:_ -> []
              end,
    Items = [format_plugin(P) || P <- Plugins],
    hecate_api_utils:json_ok(#{items => Items, total => length(Items)}, Req0).

format_plugin(#{name := Name, callback := Cb} = Plugin) ->
    Health = try check_health(Cb)
             catch _:_ -> <<"unknown">>
             end,
    HasFrontend = maps:get(has_frontend, Plugin, false),
    StoreId = maps:get(store_id, Plugin, null),
    Version = maps:get(version, Plugin, null),
    LoadedAt = maps:get(loaded_at, Plugin, null),
    #{
        name => Name,
        version => Version,
        callback_module => atom_to_binary(Cb),
        store_id => format_store_id(StoreId),
        has_frontend => HasFrontend,
        health => Health,
        loaded_at => LoadedAt
    };
format_plugin(Other) ->
    #{
        name => iolist_to_binary(io_lib:format("~p", [Other])),
        version => null,
        callback_module => null,
        store_id => null,
        has_frontend => false,
        health => <<"unknown">>,
        loaded_at => null
    }.

check_health(Cb) ->
    case erlang:function_exported(Cb, health, 0) of
        false -> <<"ok">>;
        true ->
            case Cb:health() of
                ok -> <<"ok">>;
                degraded -> <<"degraded">>;
                {unhealthy, Reason} -> Reason;
                Other -> iolist_to_binary(io_lib:format("~p", [Other]))
            end
    end.

format_store_id(null) -> null;
format_store_id(undefined) -> null;
format_store_id(Id) when is_atom(Id) -> atom_to_binary(Id);
format_store_id(Id) when is_binary(Id) -> Id;
format_store_id(Id) -> iolist_to_binary(io_lib:format("~p", [Id])).
