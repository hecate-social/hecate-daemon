-module(get_venture_tasks_api).
-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    handle(Method, Req0, State).

handle(<<"GET">>, Req0, State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case get_venture_tasks:execute(VentureId) of
        {ok, TaskList} ->
            Body = json:encode(#{ok => true, result => TaskList}),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Body, Req0),
            {ok, Req, State};
        {error, not_found} ->
            Body = json:encode(#{ok => false, error => <<"venture not found">>}),
            Req = cowboy_req:reply(404,
                #{<<"content-type">> => <<"application/json">>},
                Body, Req0),
            {ok, Req, State}
    end;
handle(_, Req0, State) ->
    Body = json:encode(#{ok => false, error => <<"method not allowed">>}),
    Req = cowboy_req:reply(405,
        #{<<"content-type">> => <<"application/json">>},
        Body, Req0),
    {ok, Req, State}.
