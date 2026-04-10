%%% @doc Relay neighborhood endpoint: GET /api/mesh/neighborhood
%%%
%%% Returns the node's view of the relay mesh — current relay connection
%%% and ranked list of nearby alternatives from the discovery cache.
%%% @end
-module(relay_neighborhood_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/neighborhood", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, State) ->
    {ok, Neighborhood} = hecate_mesh:get_neighborhood(),
    Response = sanitize_neighborhood(Neighborhood),
    Body = json:encode(maps:put(ok, true, Response)),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.

sanitize_neighborhood(#{nearby_relays := Relays} = N) ->
    N#{nearby_relays => [sanitize_relay(R) || R <- Relays]}.

sanitize_relay(R) when is_map(R) ->
    maps:map(fun(_K, undefined) -> null; (_K, V) -> V end, R);
sanitize_relay(R) -> R.
