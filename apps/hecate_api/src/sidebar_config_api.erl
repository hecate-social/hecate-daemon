%%% @doc Cowboy handler for sidebar configuration.
%%%
%%% GET  /api/config/sidebar - Returns sidebar groups from YAML config
%%% PUT  /api/config/sidebar - Saves sidebar groups to YAML config
%%% @end
-module(sidebar_config_api).

-export([init/2, routes/0]).

routes() ->
    [{"/api/config/sidebar", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get(Req0, State);
        <<"PUT">> ->
            handle_put(Req0, State);
        _ ->
            Req = cowboy_req:reply(405, #{
                <<"content-type">> => <<"application/json">>
            }, json:encode(#{ok => false, error => <<"method_not_allowed">>}), Req0),
            {ok, Req, State}
    end.

handle_get(Req0, State) ->
    case sidebar_config:read() of
        {ok, Groups} ->
            reply_json(200, #{ok => true, groups => Groups}, Req0, State);
        {error, Reason} ->
            reply_json(500, #{ok => false, error => format_error(Reason)}, Req0, State)
    end.

handle_put(Req0, State) ->
    case read_body(Req0) of
        {ok, Body, Req1} ->
            case parse_put_body(Body) of
                {ok, Groups} ->
                    case sidebar_config:write(Groups) of
                        ok ->
                            reply_json(200, #{ok => true}, Req1, State);
                        {error, Reason} ->
                            reply_json(500, #{ok => false, error => format_error(Reason)}, Req1, State)
                    end;
                {error, Reason} ->
                    reply_json(400, #{ok => false, error => format_error(Reason)}, Req1, State)
            end;
        {error, Req1} ->
            reply_json(400, #{ok => false, error => <<"bad_request">>}, Req1, State)
    end.

read_body(Req0) ->
    case cowboy_req:read_body(Req0) of
        {ok, Data, Req1} -> {ok, Data, Req1};
        {more, _, Req1} -> {error, Req1}
    end.

parse_put_body(Body) ->
    try
        Decoded = json:decode(Body),
        case Decoded of
            #{<<"groups">> := GroupsList} when is_list(GroupsList) ->
                Groups = [normalize_group(G) || G <- GroupsList],
                {ok, Groups};
            _ ->
                {error, <<"missing 'groups' array">>}
        end
    catch
        _:_ ->
            {error, <<"invalid JSON">>}
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

reply_json(Status, Response, Req0, State) ->
    Req = cowboy_req:reply(Status, #{
        <<"content-type">> => <<"application/json">>
    }, json:encode(Response), Req0),
    {ok, Req, State}.

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
