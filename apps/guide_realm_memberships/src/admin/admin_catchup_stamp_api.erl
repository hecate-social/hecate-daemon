%%% @doc Admin endpoint: POST /api/admin/realms/:realm/catchup_stamp
%%%
%%% Body: `{"at": <millis>}` (optional; defaults to now).
%%%
%%% Sets the per-realm `last_license_catchup_at` stamp directly via
%%% `hecate_license_guard:stamp_catchup/2`. The fleet CT suite uses
%%% this to roll the stamp into the past (testing the staleness
%%% guard) without waiting 24h for the threshold to elapse.
%%%
%%% Bearer-auth gated; returns 503 if HECATE_ADMIN_TOKEN unset.
%%% @end
-module(admin_catchup_stamp_api).

-export([init/2, routes/0]).

routes() -> [{"/api/admin/realms/:realm/catchup_stamp", ?MODULE, []}].

init(Req0, State) ->
    case hecate_admin_auth:authorise(Req0) of
        ok            -> dispatch(Req0, State);
        {error, _, R} -> {ok, R, State}
    end.

dispatch(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0) ->
    Realm = cowboy_req:binding(realm, Req0),
    case Realm of
        <<>>      -> hecate_api_utils:json_error(400, <<"missing realm">>, Req0);
        undefined -> hecate_api_utils:json_error(400, <<"missing realm">>, Req0);
        _         -> read_body_and_stamp(Realm, Req0)
    end.

read_body_and_stamp(Realm, Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    At = parse_at(Body),
    hecate_license_guard:stamp_catchup(Realm, At),
    Stamped = hecate_license_guard:last_catchup(Realm),
    hecate_api_utils:json_ok(#{
        realm => Realm,
        last_license_catchup_at => Stamped,
        intent => At
    }, Req1).

parse_at(<<>>) -> erlang:system_time(millisecond);
parse_at(Bin) ->
    try json:decode(Bin) of
        #{<<"at">> := V} when is_integer(V) -> V;
        #{at := V} when is_integer(V)       -> V;
        _                                    -> erlang:system_time(millisecond)
    catch _:_ ->
        erlang:system_time(millisecond)
    end.
