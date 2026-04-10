%%% @doc Mesh activation endpoint.
%%%
%%% POST /api/mesh/activate — starts relay connections, drains pending
%%% subscriptions/advertisements, runs mesh proof ceremony.
%%% Called by hecate-web after the UI is fully rendered.
%%%
%%% GET /api/mesh/activate — returns activation status.
%%% @end
-module(activate_mesh_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/activate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, State) ->
    case hecate_mesh:activate() of
        ok ->
            Response = #{ok => true, activated => true},
            Body = json:encode(Response),
            Req = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>
            }, Body, Req0),
            {ok, Req, State};
        {error, already_activated} ->
            Response = #{ok => true, activated => true, already => true},
            Body = json:encode(Response),
            Req = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>
            }, Body, Req0),
            {ok, Req, State}
    end.

handle_get(Req0, State) ->
    Activated = hecate_mesh:is_activated(),
    Connected = hecate_mesh:is_connected(),
    Response = #{ok => true, activated => Activated, connected => Connected},
    Body = json:encode(Response),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.
