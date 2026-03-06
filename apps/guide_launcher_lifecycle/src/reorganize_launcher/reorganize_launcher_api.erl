%%% @doc PUT /api/launcher/layout — full launcher layout reorganization.
%%%
%%% Route is owned by get_launcher_layout_api (QRY), which delegates
%%% PUT requests here. This module does NOT register its own route.
%%% @end
-module(reorganize_launcher_api).

-export([handle_put/1]).

handle_put(Req0) ->
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
