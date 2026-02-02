%%%-------------------------------------------------------------------
%%% @doc Identity endpoint.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_identity).

-export([init/2]).

%% @doc Get pairing status, returning 'unknown' if pairing service unavailable.
get_pairing_status_safe() ->
    case whereis(hecate_pairing) of
        undefined -> unknown;
        _Pid ->
            Status = hecate_pairing:get_status(),
            maps:get(status, Status, unknown)
    end.

init(Req0, State) ->
    Response = case hecate_identity:is_initialized() of
        true ->
            {ok, MRI} = hecate_identity:get_mri(),
            {ok, Realm} = hecate_identity:get_realm(),
            {ok, PubKey} = hecate_identity:get_public_key(),
            PairingStatus = get_pairing_status_safe(),
            #{
                ok => true,
                mri => MRI,
                realm => Realm,
                public_key => base64:encode(PubKey),
                pairing_status => PairingStatus
            };
        false ->
            #{
                ok => false,
                error => <<"not_initialized">>,
                hint => <<"Run 'hecate init' to create identity">>
            }
    end,
    Body = json:encode(Response),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.
