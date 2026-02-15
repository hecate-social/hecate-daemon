%%% @doc API handler: POST /api/irc/channels/:channel_id/messages
%%%
%%% Sends a message to an IRC channel. The message is published to the mesh
%%% topic hecate.irc.msg.{channel_id} and also broadcast to local pg for
%%% loopback (so the sender sees their own message).
%%% @end
-module(relay_irc_message_api).

-export([init/2]).

-dialyzer({nowarn_function, [handle_post/2]}).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ChannelId = cowboy_req:binding(channel_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            Content = hecate_api_utils:get_field(content, Params),
            Nick = hecate_api_utils:get_field(nick, Params, <<"anon">>),
            case Content of
                undefined ->
                    hecate_api_utils:bad_request(<<"content is required">>, Req1);
                _ ->
                    MsgPayload = #{
                        <<"type">> => <<"message">>,
                        <<"channel_id">> => ChannelId,
                        <<"nick">> => Nick,
                        <<"content">> => Content,
                        <<"timestamp">> => erlang:system_time(millisecond)
                    },
                    MeshTopic = <<"hecate.irc.msg.", ChannelId/binary>>,
                    %% Publish to mesh for remote peers
                    hecate_mesh_client:publish(MeshTopic, MsgPayload),
                    %% Also broadcast locally (loopback for sender)
                    PgGroup = {irc_msg, ChannelId},
                    Members = pg:get_members(pg, PgGroup),
                    Msg = {irc_msg, ChannelId, MsgPayload},
                    lists:foreach(fun(Pid) -> Pid ! Msg end, Members),
                    hecate_api_utils:json_ok(#{sent => true}, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.
