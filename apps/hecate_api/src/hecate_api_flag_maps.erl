%%% @doc GET /api/flag-maps — returns all daemon aggregate flag maps.
%%%
%%% Enables frontends to decode raw status integers into human-readable
%%% labels using the TypeScript BitFlags library (@hecate-social/sdk).
%%%
%%% Response:
%%%   {
%%%     "plugin_aggregate":  { "1": "Installed", "2": "Removed", ... },
%%%     "license_aggregate": { "1": "Initiated", "2": "Accepted", ... },
%%%     ...
%%%   }
%%% @end
-module(hecate_api_flag_maps).

-export([init/2, routes/0]).

routes() -> [{"/api/flag-maps", ?MODULE, []}].

%% All daemon aggregates that expose flag_map/0.
-define(AGGREGATES, [
    {<<"plugin_aggregate">>,           plugin_aggregate},
    {<<"license_aggregate">>,          license_aggregate},
    {<<"license_offering_aggregate">>, license_offering_aggregate},
    {<<"procurement_aggregate">>,      procurement_aggregate},
    {<<"sale_aggregate">>,             sale_aggregate},
    {<<"payment_aggregate">>,          payment_aggregate},
    {<<"launcher_aggregate">>,         launcher_aggregate}
]).

init(Req0, State) ->
    FlagMaps = collect_flag_maps(),
    Body = json:encode(FlagMaps),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.

collect_flag_maps() ->
    lists:foldl(fun({Name, Mod}, Acc) ->
        case safe_flag_map(Mod) of
            #{} = Map when map_size(Map) > 0 ->
                Acc#{Name => integer_keys_to_binary(Map)};
            _ ->
                Acc
        end
    end, #{}, ?AGGREGATES).

safe_flag_map(Mod) ->
    try Mod:flag_map()
    catch _:_ -> #{}
    end.

%% JSON keys must be strings — convert integer flag values to binaries.
integer_keys_to_binary(Map) ->
    maps:fold(fun(K, V, Acc) when is_integer(K) ->
        Acc#{integer_to_binary(K) => V};
    (K, V, Acc) ->
        Acc#{K => V}
    end, #{}, Map).
