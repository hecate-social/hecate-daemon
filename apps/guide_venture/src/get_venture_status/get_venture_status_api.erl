-module(get_venture_status_api).
-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    handle(Method, Req0, State).

handle(<<"GET">>, Req0, State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case get_venture_status:execute(VentureId) of
        {ok, Status} ->
            Body = json:encode(#{ok => true, status => format_status(Status)}),
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

format_status(#{divisions := Divisions} = Status) ->
    FormattedDivisions = lists:map(fun format_division/1, Divisions),
    maps:put(divisions, FormattedDivisions, maps:remove(divisions, Status));
format_status(Status) ->
    Status.

format_division(#{processes := Processes} = Div) ->
    %% Convert atom values to binaries for JSON encoding
    FormattedProcesses = maps:map(fun(_K, V) -> atom_to_binary(V) end, Processes),
    Div#{processes => FormattedProcesses,
         current_process => atom_to_binary(maps:get(current_process, Div, unknown))};
format_division(Div) ->
    Div.
