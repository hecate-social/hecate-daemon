%%% @doc POST /api/mesh/call — Invoke a procedure advertised on the mesh.
%%%
%%% Request:  #{<<"procedure">> => <<"mri:proc:realm:foo.bar">>,
%%%             <<"args">>      => #{...} | null,
%%%             <<"timeout_ms">> => non_neg_integer() | undefined}
%%%
%%% Response: #{ok => true,  result => Term, duration_ms => N}
%%%           #{ok => false, error => <<...>>, duration_ms => N}
%%%
%%% Macula RPC is procedure-addressed: the pool routes to whichever peer
%%% has advertised `Procedure'. The realm is implicit (this daemon's
%%% realm membership). v1 is unary — `streaming_rpc' is not yet shipped
%%% cross-station; promote to call_stream once it is.
%%%
%%% Replaces, for the mesh path, the older /api/rpc/call which is a stub
%%% kept around for unrelated TUI consumers.
%%% @end
-module(call_mesh_api).

-export([init/2, routes/0]).

-define(DEFAULT_TIMEOUT_MS, 30000).
-define(MAX_TIMEOUT_MS,    300000).

routes() -> [{"/api/mesh/call", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            dispatch(Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"invalid JSON">>, Req1)
    end.

dispatch(Body, Req) ->
    case procedure(Body) of
        undefined ->
            hecate_api_utils:bad_request(<<"procedure is required">>, Req);
        Proc when not is_binary(Proc) ->
            hecate_api_utils:bad_request(<<"procedure must be a string">>, Req);
        Proc ->
            Args = case args(Body) of
                undefined -> #{};
                null      -> #{};
                M when is_map(M) -> M;
                _         -> #{}
            end,
            Timeout = clamp_timeout(timeout_ms(Body)),
            T0 = erlang:monotonic_time(millisecond),
            Result = hecate_mesh:call(Proc, Args, Timeout),
            Dur = erlang:monotonic_time(millisecond) - T0,
            reply(Result, Dur, Req)
    end.

reply({ok, ResultData}, Dur, Req) ->
    hecate_api_utils:json_ok(#{result => ResultData, duration_ms => Dur}, Req);
reply({error, Reason}, Dur, Req) ->
    hecate_api_utils:json_response(502, #{
        ok          => false,
        error       => hecate_api_utils:format_error(Reason),
        duration_ms => Dur
    }, Req).

procedure(Body)   -> hecate_api_utils:get_field(procedure, Body).
args(Body)        -> hecate_api_utils:get_field(args, Body).
timeout_ms(Body)  -> hecate_api_utils:get_field(timeout_ms, Body).

clamp_timeout(undefined) -> ?DEFAULT_TIMEOUT_MS;
clamp_timeout(N) when is_integer(N), N > 0, N =< ?MAX_TIMEOUT_MS -> N;
clamp_timeout(_) -> ?DEFAULT_TIMEOUT_MS.
