%%% @doc Cowboy handler for sidebar configuration.
%%%
%%% GET  /api/config/sidebar - Returns sidebar groups from YAML config
%%% PUT  /api/config/sidebar - Saves sidebar groups to YAML config
%%% @end
-module(sidebar_config_api).

-export([init/2, routes/0]).

routes() ->
    [{"/api/config/sidebar", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get(Req0);
        <<"PUT">> ->
            handle_put(Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    case sidebar_config:read() of
        {ok, Groups} ->
            hecate_api_utils:json_ok(#{groups => Groups}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

handle_put(Req0) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"groups">> := GroupsList}, Req1} when is_list(GroupsList) ->
            Groups = [normalize_group(G) || G <- GroupsList],
            case sidebar_config:write(Groups) of
                ok ->
                    hecate_api_utils:json_ok(#{}, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req1)
            end;
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"missing 'groups' array">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"invalid JSON">>, Req1)
    end.

normalize_group(#{<<"name">> := Name} = G) ->
    #{
        name => Name,
        icon => maps:get(<<"icon">>, G, <<"\xF0\x9F\x93\x81">>),
        collapsed => maps:get(<<"collapsed">>, G, false),
        apps => maps:get(<<"apps">>, G, [])
    };
normalize_group(_) ->
    #{name => <<>>, icon => <<"\xF0\x9F\x93\x81">>, collapsed => false, apps => []}.
