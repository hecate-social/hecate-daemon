%%% @doc Broadcast helper for pushing domain events to web frontend connections.
%%%
%%% Stateless module. Any gen_server can call broadcast/2 to push an event
%%% to all connected SSE clients (via the web_connections pg group).
%%% @end
-module(hecate_web_events).

-export([broadcast/2]).

-define(SCOPE, pg).
-define(GROUP, web_connections).

-spec broadcast(atom(), map()) -> ok.
broadcast(EventType, Data) ->
    TypeBin = atom_to_binary(EventType),
    JsonBin = iolist_to_binary(json:encode(Data)),
    Members = pg:get_members(?SCOPE, ?GROUP),
    [Pid ! {web_event, TypeBin, JsonBin} || Pid <- Members],
    ok.
