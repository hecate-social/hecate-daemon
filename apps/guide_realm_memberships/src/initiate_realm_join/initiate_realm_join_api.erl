%%% @doc API handler: POST /api/realms/join/initiate
%%%
%%% Starts a new realm join session via hecate_realm_session gen_server.
-module(initiate_realm_join_api).
-export([init/2, routes/0]).

routes() -> [{"/api/realms/join/initiate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    RealmUrl = maps:get(<<"realm_url">>, Decoded, <<"https://macula.io">>),
    case hecate_realm_session:start_joining(#{realm_url => RealmUrl}) of
        {ok, SessionData} ->
            hecate_api_utils:json_ok(SessionData, Req1);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req1)
    end.
