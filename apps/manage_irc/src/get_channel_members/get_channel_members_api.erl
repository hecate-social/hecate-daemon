%%% @doc API handler: GET /api/irc/channels/:channel_id/members
%%%
%%% Returns the list of members currently connected to a channel.
%%% Queries SSE stream handler PIDs from the pg group and collects
%%% nick/node_id info from each.
%%% @end
-module(get_channel_members_api).

-export([init/2]).

-define(SCOPE, pg).
-define(INFO_TIMEOUT_MS, 2000).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    ChannelId = cowboy_req:binding(channel_id, Req0),
    Pids = pg:get_members(?SCOPE, {irc_msg, ChannelId}),
    AllMembers = collect_member_info(Pids),
    Members = dedup_by_node_id(AllMembers),
    hecate_api_utils:json_ok(#{channel_id => ChannelId, members => Members}, Req0).

collect_member_info(Pids) ->
    Self = self(),
    Ref = make_ref(),
    %% Ask each SSE handler for its info
    lists:foreach(fun(Pid) ->
        Pid ! {get_info, {Self, Ref}}
    end, Pids),
    %% Collect replies with timeout
    collect_replies(Ref, length(Pids), [], ?INFO_TIMEOUT_MS).

collect_replies(_Ref, 0, Acc, _Timeout) ->
    Acc;
collect_replies(Ref, Remaining, Acc, Timeout) ->
    receive
        {stream_info, Ref, Info} ->
            collect_replies(Ref, Remaining - 1, [Info | Acc], Timeout)
    after Timeout ->
        Acc
    end.

%% Multiple SSE handlers may exist for the same node (reconnects, HMR).
%% Keep only one entry per node_id to avoid duplicate members.
dedup_by_node_id(Members) ->
    maps:values(lists:foldl(fun(#{<<"node_id">> := NodeId} = M, Acc) ->
        Acc#{NodeId => M}
    end, #{}, Members)).
