%%% @doc GET /api/lan/nodes — List discovered machines on the LAN.
%%%
%%% Returns all machines found via ARP + hostname resolution + hecate probing.
%%% POST /api/lan/scan — Trigger an immediate rescan.
%%% @end
-module(get_lan_nodes_api).

-export([init/2, routes/0]).

routes() ->
    [{"/api/lan/nodes", ?MODULE, []},
     {"/api/lan/scan", ?MODULE, []},
     {"/api/lan/dismiss/:mac", ?MODULE, []}].

init(Req0, State) ->
    case {cowboy_req:method(Req0), cowboy_req:path(Req0)} of
        {<<"GET">>, <<"/api/lan/nodes">>} -> handle_get(Req0, State);
        {<<"POST">>, <<"/api/lan/scan">>} -> handle_scan(Req0, State);
        {<<"POST">>, _} ->
            case cowboy_req:binding(mac, Req0) of
                undefined -> hecate_api_utils:not_found(Req0);
                MAC -> handle_dismiss(MAC, Req0, State)
            end;
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    {ok, Nodes} = lan_scanner:get_nodes(),
    Formatted = lists:map(fun format_node/1, Nodes),
    %% Separate into hecate nodes and bare machines
    {HecateNodes, BareNodes} = lists:partition(
        fun(#{<<"hecate">> := H}) -> maps:get(<<"running">>, H, false) end,
        Formatted),
    hecate_api_utils:json_ok(#{
        nodes => Formatted,
        hecate_count => length(HecateNodes),
        bare_count => length(BareNodes),
        total => length(Formatted)
    }, Req0).

handle_scan(Req0, _State) ->
    lan_scanner:scan_now(),
    hecate_api_utils:json_ok(#{scanning => true}, Req0).

handle_dismiss(MAC, Req0, _State) ->
    case maybe_dismiss_lan_machine:dispatch(MAC) of
        {ok, _V, _Events} ->
            hecate_api_utils:json_ok(#{dismissed => true, mac => MAC}, Req0);
        {error, already_dismissed} ->
            hecate_api_utils:json_ok(#{dismissed => true, mac => MAC}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, iolist_to_binary(io_lib:format("~p", [Reason])), Req0)
    end.

%% @private Format a node for JSON output.
format_node(#{ip := IP, hostname := Hostname, mac := MAC,
              ssh_available := SSH, hecate := Hecate} = Node) ->
    #{
        <<"ip">> => list_to_binary(IP),
        <<"hostname">> => Hostname,
        <<"mac">> => list_to_binary(MAC),
        <<"interface">> => list_to_binary(maps:get(interface, Node, "")),
        <<"ssh">> => SSH,
        <<"hecate">> => format_hecate(Hecate)
    };
format_node(#{ip := IP} = Node) ->
    #{
        <<"ip">> => list_to_binary(IP),
        <<"hostname">> => maps:get(hostname, Node, list_to_binary(IP)),
        <<"mac">> => list_to_binary(maps:get(mac, Node, "unknown")),
        <<"interface">> => list_to_binary(maps:get(interface, Node, "")),
        <<"ssh">> => maps:get(ssh_available, Node, false),
        <<"hecate">> => #{<<"running">> => false}
    }.

format_hecate(#{running := true} = H) ->
    #{
        <<"running">> => true,
        <<"version">> => maps:get(version, H, <<"unknown">>),
        <<"status">> => maps:get(status, H, <<"unknown">>),
        <<"ready">> => maps:get(ready, H, false)
    };
format_hecate(_) ->
    #{<<"running">> => false}.
