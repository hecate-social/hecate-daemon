%%% @doc Mesh subscriber discovery endpoint: GET /api/mesh/discover?topic=...
%%%
%%% Returns the list of subscribers for a given mesh topic.
%%% @end
-module(discover_mesh_subscribers_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/discover", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get(Req0, State);
        _ ->
            Req = cowboy_req:reply(405, #{
                <<"content-type">> => <<"application/json">>
            }, <<"{\"ok\":false,\"error\":\"method_not_allowed\"}">>, Req0),
            {ok, Req, State}
    end.

handle_get(Req0, State) ->
    QsVals = cowboy_req:parse_qs(Req0),
    case lists:keyfind(<<"topic">>, 1, QsVals) of
        {<<"topic">>, Topic} when is_binary(Topic), byte_size(Topic) > 0 ->
            handle_discover(Topic, Req0, State);
        _ ->
            reply_json(400, #{ok => false, error => <<"missing topic parameter">>}, Req0, State)
    end.

handle_discover(Topic, Req0, State) ->
    case hecate_mesh:is_connected() of
        false ->
            reply_json(503, #{ok => false, error => <<"not connected to mesh">>}, Req0, State);
        true ->
            case hecate_mesh:discover_subscribers(Topic) of
                {ok, Subscribers} ->
                    Formatted = [format_subscriber(S) || S <- Subscribers],
                    reply_json(200, #{ok => true, topic => Topic, subscribers => Formatted}, Req0, State);
                {error, Reason} ->
                    ErrBin = iolist_to_binary(io_lib:format("~p", [Reason])),
                    reply_json(500, #{ok => false, error => ErrBin}, Req0, State)
            end
    end.

format_subscriber(Sub) when is_map(Sub) ->
    Sub;
format_subscriber({NodeId, Endpoint}) ->
    #{node_id => format_binary(NodeId), endpoint => format_binary(Endpoint)};
format_subscriber(Other) ->
    #{raw => iolist_to_binary(io_lib:format("~p", [Other]))}.

format_binary(Bin) when is_binary(Bin) -> Bin;
format_binary(Other) -> iolist_to_binary(io_lib:format("~p", [Other])).

reply_json(StatusCode, Body, Req0, State) ->
    Encoded = json:encode(Body),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, Encoded, Req0),
    {ok, Req, State}.
