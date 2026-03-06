%%% @doc API handler: PUT /api/launcher/layout
%%%
%%% Full launcher layout reorganization.
%%% Lives in the reorganize_launcher desk for vertical slicing.
%%% @end
-module(reorganize_launcher_api).

-export([init/2, routes/0]).

routes() -> [{"/api/launcher/layout", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"PUT">> -> handle_put(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_put(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_reorganize(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_reorganize(Params, Req) ->
    Groups = hecate_api_utils:get_field(groups, Params),
    case Groups of
        undefined ->
            hecate_api_utils:bad_request(<<"groups is required">>, Req);
        _ when not is_list(Groups) ->
            hecate_api_utils:bad_request(<<"groups must be an array">>, Req);
        _ ->
            create_and_dispatch(Groups, Req)
    end.

create_and_dispatch(Groups, Req) ->
    CmdParams = #{groups => Groups},
    case reorganize_launcher_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_reorganize_launcher:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                version => Version,
                events  => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
