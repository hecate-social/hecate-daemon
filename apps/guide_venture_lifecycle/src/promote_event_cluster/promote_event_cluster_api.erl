%%% @doc API handler: POST /api/ventures/:venture_id/storm/cluster/:cluster_id/promote
%%%
%%% Promotes an event cluster to a division during Big Picture Event Storming.
%%% @end
-module(promote_event_cluster_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    ClusterId = cowboy_req:binding(cluster_id, Req0),
    case promote_event_cluster_v1:new(#{
        venture_id => VentureId,
        cluster_id => ClusterId
    }) of
        {ok, Cmd} ->
            case maybe_promote_event_cluster:dispatch(Cmd) of
                {ok, Version, Events} ->
                    DivisionId = extract_division_id(Events),
                    Body2 = #{
                        venture_id => VentureId,
                        cluster_id => ClusterId,
                        division_id => DivisionId,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(201, Body2, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.

extract_division_id([#{<<"division_id">> := DivId} | _]) -> DivId;
extract_division_id([#{division_id := DivId} | _]) -> DivId;
extract_division_id([_ | Rest]) -> extract_division_id(Rest);
extract_division_id([]) -> undefined.
