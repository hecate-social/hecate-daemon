%%% @doc Join code API endpoints.
%%%
%%% POST /api/site/join-code   — Generate a self-contained join token
%%% GET  /api/site/join-codes  — List active display codes
%%% @end
-module(join_code_api).

-export([init/2, routes/0]).

routes() ->
    [{"/api/site/join-code", ?MODULE, []},
     {"/api/site/join-codes", ?MODULE, []}].

init(Req0, State) ->
    case {cowboy_req:method(Req0), cowboy_req:path(Req0)} of
        {<<"POST">>, <<"/api/site/join-code">>}  -> handle_generate(Req0, State);
        {<<"GET">>,  <<"/api/site/join-codes">>}  -> handle_list(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_generate(Req0, _State) ->
    case join_code_server:generate() of
        {ok, #{display_code := Code, token := Token, expires_in := Exp}} ->
            hecate_api_utils:json_ok(#{
                display_code => Code,
                token => Token,
                expires_in => Exp
            }, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, format_error(Reason), Req0)
    end.

handle_list(Req0, _State) ->
    Active = join_code_server:list_active(),
    hecate_api_utils:json_ok(#{codes => Active, count => length(Active)}, Req0).

format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
