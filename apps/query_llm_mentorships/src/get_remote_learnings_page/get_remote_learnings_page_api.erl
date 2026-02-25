-module(get_remote_learnings_page_api).
-export([init/2, routes/0]).

routes() -> [{"/api/mentors/remote", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case get_remote_learnings_page:execute(Filters) of
        {ok, Remote} ->
            hecate_api_utils:json_ok(#{remote_learnings => Remote}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

build_filters(QS) ->
    lists:foldl(fun({K, V}, Acc) ->
        case K of
            <<"domain">> -> Acc#{domain => V};
            <<"category">> -> Acc#{category => V};
            <<"status">> ->
                case catch binary_to_integer(V) of
                    I when is_integer(I) -> Acc#{status_mask => I};
                    _ -> Acc
                end;
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
