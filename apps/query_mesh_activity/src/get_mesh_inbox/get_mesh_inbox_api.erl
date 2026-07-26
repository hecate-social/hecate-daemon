%%% @doc GET /api/mesh/inbox[?since=<ms>&topic=<t>&limit=<n>]
%%%
%%% Filtered view of `mesh_activity' returning only inbound events
%%% (kind = `mesh_fact_received'). Optional `topic' filter matches
%%% `payload.topic' exactly. `since' is epoch ms; `limit' caps the
%%% returned list.
%%%
%%% Response:
%%%   #{ok => true,
%%%     events => [
%%%       #{fact_id => <<...>>, kind => <<"mesh_fact_received">>,
%%%         ts_ms => N, payload => #{direction => <<"in">>, topic => ...,
%%%                                  fact => ..., sender_node_id => ...,
%%%                                  sender_mri => ..., sig_verified => ...}}
%%%     ]}
%%% @end
-module(get_mesh_inbox_api).

-export([init/2, routes/0]).

-define(KIND_RECEIVED, <<"mesh_fact_received">>).
-define(DEFAULT_LIMIT, 200).
-define(OVERFETCH_FACTOR, 4).

routes() -> [{"/api/mesh/inbox", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Qs    = cowboy_req:parse_qs(Req0),
    Since = parse_int(proplists:get_value(<<"since">>, Qs), 0),
    Limit = parse_int(proplists:get_value(<<"limit">>, Qs), ?DEFAULT_LIMIT),
    Topic = proplists:get_value(<<"topic">>, Qs),
    {ok, AllSince} = project_mesh_activity_store:since(Since, Limit * ?OVERFETCH_FACTOR),
    Inbound = [E || E <- AllSince, is_inbound(E)],
    Filtered = filter_topic(Inbound, Topic),
    Capped = lists:sublist(Filtered, Limit),
    hecate_api_utils:json_ok(#{events => Capped}, Req0).

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

is_inbound(#{kind := ?KIND_RECEIVED}) -> true;
is_inbound(_) -> false.

filter_topic(Events, undefined) -> Events;
filter_topic(Events, TopicBin) when is_binary(TopicBin) ->
    [E || E <- Events, event_topic(E) =:= TopicBin].

event_topic(#{payload := #{topic := T}}) -> T;
event_topic(_) -> undefined.

parse_int(undefined, Default) -> Default;
parse_int(Bin, Default) when is_binary(Bin) ->
    try binary_to_integer(Bin) of
        N when is_integer(N) -> N
    catch
        _:_ -> Default
    end;
parse_int(_, Default) -> Default.
