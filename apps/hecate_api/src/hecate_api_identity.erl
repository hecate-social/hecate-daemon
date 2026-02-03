%%%-------------------------------------------------------------------
%%% @doc Identity endpoint.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_identity).

-export([init/2]).

%% Routes:
%% GET  /identity      -> get identity info
%% POST /identity/init -> initialize identity

%% @doc Get pairing status, returning 'unknown' if pairing service unavailable.
get_pairing_status_safe() ->
    case whereis(hecate_pairing) of
        undefined -> unknown;
        _Pid ->
            Status = hecate_pairing:get_status(),
            maps:get(status, Status, unknown)
    end.

init(Req0, [do_init]) ->
    handle_init(Req0);
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

%% POST /identity/init - Initialize identity
handle_init(Req0) ->
    case hecate_identity:initialize(#{}) of
        ok ->
            {ok, MRI} = hecate_identity:get_mri(),
            {ok, Realm} = hecate_identity:get_realm(),
            {ok, PubKey} = hecate_identity:get_public_key(),
            Response = #{
                ok => true,
                mri => MRI,
                realm => Realm,
                public_key => base64:encode(PubKey)
            },
            reply_json(201, Response, Req0);
        {error, already_initialized} ->
            Response = #{
                ok => false,
                error => <<"already_initialized">>,
                hint => <<"Identity already exists">>
            },
            reply_json(409, Response, Req0);
        {error, Reason} ->
            Response = #{
                ok => false,
                error => iolist_to_binary(io_lib:format("~p", [Reason]))
            },
            reply_json(500, Response, Req0)
    end.

reply_json(Status, Response, Req0) ->
    Body = json:encode(Response),
    Req = cowboy_req:reply(Status, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, []}.
