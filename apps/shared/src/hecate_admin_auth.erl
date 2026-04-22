%%% @doc Bearer-token gate for admin endpoints.
%%%
%%% Admin endpoints (introspection, state mutation hooks for tests
%%% + operations) are off by default. Set the
%%% `HECATE_ADMIN_TOKEN` env var (read once at startup) to enable
%%% them; clients then pass `Authorization: Bearer <token>`.
%%%
%%% If the env var is unset, every admin endpoint returns 503
%%% `admin_disabled` regardless of headers. This means the deployed
%%% daemon defaults to safe — only nodes the operator explicitly
%%% enables expose the surface.
%%% @end
-module(hecate_admin_auth).

-export([authorise/1]).

-spec authorise(cowboy_req:req()) -> ok | {error, atom(), cowboy_req:req()}.
authorise(Req0) ->
    case configured_token() of
        undefined ->
            Req1 = hecate_api_utils:json_error(
                503,
                <<"Admin endpoints disabled — set HECATE_ADMIN_TOKEN">>,
                Req0),
            {error, admin_disabled, Req1};
        Token when is_binary(Token), byte_size(Token) > 0 ->
            check_header(Token, Req0)
    end.

check_header(ExpectedToken, Req0) ->
    case cowboy_req:header(<<"authorization">>, Req0) of
        <<"Bearer ", Provided/binary>> ->
            case const_eq(Provided, ExpectedToken) of
                true  -> ok;
                false -> deny(<<"invalid_token">>, Req0)
            end;
        undefined ->
            deny(<<"missing_authorization">>, Req0);
        _Other ->
            deny(<<"bad_authorization_scheme">>, Req0)
    end.

deny(Reason, Req0) ->
    Req1 = hecate_api_utils:json_error(401, Reason, Req0),
    {error, unauthorized, Req1}.

%% @private Constant-time binary comparison so the wrong-token branch
%% doesn't leak length / prefix hints to a remote attacker.
const_eq(A, B) when is_binary(A), is_binary(B), byte_size(A) =/= byte_size(B) ->
    %% Different sizes always false, but compare anyway to keep
    %% timing close to the equal-size path.
    _ = const_eq_bytes(A, A),
    false;
const_eq(A, B) ->
    const_eq_bytes(A, B) =:= 0.

const_eq_bytes(A, B) ->
    const_eq_bytes(A, B, 0).

const_eq_bytes(<<>>, <<>>, Acc) ->
    Acc;
const_eq_bytes(<<X, A/binary>>, <<Y, B/binary>>, Acc) ->
    const_eq_bytes(A, B, Acc bor (X bxor Y));
const_eq_bytes(_, _, _) ->
    1.

configured_token() ->
    case application:get_env(hecate, admin_token) of
        {ok, T} when is_binary(T), byte_size(T) > 0 -> T;
        {ok, T} when is_list(T)                     -> list_to_binary(T);
        _ ->
            case os:getenv("HECATE_ADMIN_TOKEN") of
                false                          -> undefined;
                ""                              -> undefined;
                Str when is_list(Str)           -> list_to_binary(Str)
            end
    end.
