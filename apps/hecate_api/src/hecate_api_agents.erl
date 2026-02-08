%%% @doc Agents API endpoints.
%%%
%%% Provides REST interface to Agent management (specialists and generalists):
%%% - GET  /api/agents           - List all agents
%%% - GET  /api/agents/:agent_id - Get specific agent by ID
%%%
%%% This is a skeleton implementation. Real agent management
%%% will be implemented when the manage_agents domain is ready.
%%%
%%% @end
-module(hecate_api_agents).

-export([init/2]).

%% Route: GET /api/agents
init(Req0, [list]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_list(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/agents/:agent_id
init(Req0, [get]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

init(Req0, _State) ->
    not_found(Req0).

%%% ===================================================================
%%% Handlers
%%% ===================================================================

%% @doc List all agents.
%% Skeleton implementation - returns empty list until manage_agents is ready.
handle_list(Req0) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),

    %% Try to call list_agents if available, otherwise return empty list
    case try_list_agents(Filters) of
        {ok, Agents} ->
            json_response(200, #{ok => true, agents => Agents}, Req0);
        {error, not_implemented} ->
            %% Skeleton: return empty list
            json_response(200, #{ok => true, agents => []}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

%% @doc Get agent by ID.
%% Skeleton implementation - returns not_found until manage_agents is ready.
handle_get(Req0) ->
    AgentId = cowboy_req:binding(agent_id, Req0),

    %% Try to call get_agent if available, otherwise return not_found
    case try_get_agent(AgentId) of
        {ok, Agent} ->
            json_response(200, #{ok => true, agent => Agent}, Req0);
        {error, not_found} ->
            json_response(404, #{ok => false, error => <<"Agent not found">>}, Req0);
        {error, not_implemented} ->
            %% Skeleton: agent management not yet implemented
            json_response(404, #{ok => false, error => <<"Agent not found">>}, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

%%% ===================================================================
%%% Internal helpers
%%% ===================================================================

%% @doc Try to call list_agents:execute/1 if available.
-spec try_list_agents(map()) -> {ok, [map()]} | {error, not_implemented | term()}.
try_list_agents(Filters) ->
    try
        case erlang:function_exported(list_agents, execute, 1) of
            true ->
                list_agents:execute(Filters);
            false ->
                {error, not_implemented}
        end
    catch
        error:undef ->
            {error, not_implemented};
        _:Reason ->
            {error, Reason}
    end.

%% @doc Try to call get_agent:execute/1 if available.
-spec try_get_agent(binary()) -> {ok, map()} | {error, not_found | not_implemented | term()}.
try_get_agent(AgentId) ->
    try
        case erlang:function_exported(get_agent, execute, 1) of
            true ->
                get_agent:execute(AgentId);
            false ->
                {error, not_implemented}
        end
    catch
        error:undef ->
            {error, not_implemented};
        _:Reason ->
            {error, Reason}
    end.

build_filters(QS) ->
    lists:foldl(fun({K, V}, Acc) ->
        case K of
            <<"type">> -> Acc#{type => V};
            <<"status">> -> Acc#{status => V};
            <<"torch_id">> -> Acc#{torch_id => V};
            <<"cartwheel_id">> -> Acc#{cartwheel_id => V};
            <<"limit">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{limit => I};
                    _ -> Acc
                end;
            <<"offset">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{offset => I};
                    _ -> Acc
                end;
            _ -> Acc
        end
    end, #{}, QS).

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason);
format_error({Type, Details}) ->
    iolist_to_binary(io_lib:format("~p: ~p", [Type, Details]));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

json_response(StatusCode, Body, Req0) ->
    JsonBody = json:encode(Body),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, JsonBody, Req0),
    {ok, Req, []}.

method_not_allowed(Req0) ->
    json_response(405, #{ok => false, error => <<"Method not allowed">>}, Req0).

not_found(Req0) ->
    json_response(404, #{ok => false, error => <<"Not found">>}, Req0).
