%%% @doc API handler: POST /api/ventures/:venture_id/discovery/identify
%%%
%%% Identifies a new division within a venture during discovery.
%%% @end
-module(identify_division_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    ContextName = maps:get(<<"context_name">>, Params, undefined),
    case ContextName of
        undefined ->
            hecate_api_utils:json_error(400, <<"context_name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"context_name cannot be empty">>, Req1);
        _ ->
            Description = maps:get(<<"description">>, Params, undefined),
            IdentifiedBy = maps:get(<<"identified_by">>, Params, undefined),
            case identify_division_v1:new(#{
                venture_id => VentureId,
                context_name => ContextName,
                description => Description,
                identified_by => IdentifiedBy
            }) of
                {ok, Cmd} ->
                    case maybe_identify_division:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            DivisionId = extract_division_id(Events),
                            Body2 = #{
                                venture_id => VentureId,
                                division_id => DivisionId,
                                context_name => ContextName,
                                version => Version,
                                events => Events
                            },
                            hecate_api_utils:json_reply(201, Body2, Req1);
                        {error, Reason} ->
                            hecate_api_utils:json_error(422, Reason, Req1)
                    end;
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end
    end.

extract_division_id([#{<<"division_id">> := DivId} | _]) -> DivId;
extract_division_id([#{division_id := DivId} | _]) -> DivId;
extract_division_id(_) -> undefined.
