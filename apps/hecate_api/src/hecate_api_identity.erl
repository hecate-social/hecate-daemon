%%%-------------------------------------------------------------------
%%% @doc Identity endpoint.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_identity).

-export([init/2]).

init(Req0, State) ->
    Response = case hecate_identity:is_initialized() of
        true ->
            {ok, MRI} = hecate_identity:get_mri(),
            {ok, Realm} = hecate_identity:get_realm(),
            {ok, PubKey} = hecate_identity:get_public_key(),
            #{
                ok => true,
                mri => MRI,
                realm => Realm,
                public_key => base64:encode(PubKey)
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
