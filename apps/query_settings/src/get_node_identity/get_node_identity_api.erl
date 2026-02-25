%%% @doc API handler: GET /api/node/identity
%%%
%%% Returns the node's crypto identity from hecate_identity gen_server.
%%% @end
-module(get_node_identity_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/identity", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case hecate_identity:is_initialized() of
        true ->
            {ok, MRI} = hecate_identity:get_mri(),
            {ok, PubKey} = hecate_identity:get_public_key(),
            {ok, Realm} = hecate_identity:get_realm(),
            NodeIdentity = #{
                mri => MRI,
                public_key => base64:encode(PubKey),
                realm => Realm,
                initialized => true
            },
            hecate_api_utils:json_ok(#{node_identity => NodeIdentity}, Req0);
        false ->
            hecate_api_utils:json_ok(#{node_identity => #{initialized => false}}, Req0)
    end.
