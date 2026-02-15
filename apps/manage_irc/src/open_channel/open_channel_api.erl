%%% @doc API handler: POST /api/irc/channels/open
%%% Opens a new IRC channel.
-module(open_channel_api).

-include("irc_channel_status.hrl").

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_open(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_open(Params, Req) ->
    Name = hecate_api_utils:get_field(name, Params),
    Topic = hecate_api_utils:get_field(topic, Params),
    OpenedBy = case hecate_identity:get_mri() of
        {ok, Mri} -> Mri;
        _ -> <<"anonymous">>
    end,

    case Name of
        undefined ->
            hecate_api_utils:bad_request(<<"name is required">>, Req);
        _ ->
            CmdParams = #{name => Name, topic => Topic, opened_by => OpenedBy},
            case open_channel_v1:new(CmdParams) of
                {ok, Cmd} -> dispatch(Cmd, Req);
                {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
            end
    end.

dispatch(Cmd, Req) ->
    case maybe_open_channel:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            ChannelId = open_channel_v1:get_channel_id(Cmd),
            Status = evoq_bit_flags:set(0, ?IRC_INITIATED),
            StatusLabel = evoq_bit_flags:to_string(Status, ?IRC_FLAG_MAP),
            hecate_api_utils:json_ok(201, #{
                channel_id => ChannelId,
                name => open_channel_v1:get_name(Cmd),
                topic => open_channel_v1:get_topic(Cmd),
                status => Status,
                status_label => StatusLabel,
                opened_at => erlang:system_time(millisecond),
                opened_by => open_channel_v1:get_opened_by(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
