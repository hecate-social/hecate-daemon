%%% @doc POST /api/launcher/entries — register an app entry.
%%%
%%% Route is owned by get_launcher_entries_api (QRY), which delegates
%%% POST requests here. This module does NOT register its own route.
%%% @end
-module(register_entry_api).

-export([handle_post/1]).

handle_post(Req0) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_register(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_register(Params, Req) ->
    EntryId     = hecate_api_utils:get_field(entry_id, Params),
    DisplayName = hecate_api_utils:get_field(display_name, Params),
    Icon        = hecate_api_utils:get_field(icon, Params),
    GroupName   = hecate_api_utils:get_field(group_name, Params),

    case validate(EntryId, DisplayName, GroupName) of
        ok -> create_and_dispatch(EntryId, DisplayName, Icon, GroupName, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _, _) -> {error, <<"entry_id is required">>};
validate(_, undefined, _) -> {error, <<"display_name is required">>};
validate(_, _, undefined) -> {error, <<"group_name is required">>};
validate(_, _, _) -> ok.

create_and_dispatch(EntryId, DisplayName, Icon, GroupName, Req) ->
    CmdParams = #{
        entry_id     => EntryId,
        display_name => DisplayName,
        icon         => case Icon of undefined -> <<>>; _ -> Icon end,
        group_name   => GroupName
    },
    case register_entry_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_register_entry:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                entry_id     => register_entry_v1:get_entry_id(Cmd),
                display_name => register_entry_v1:get_display_name(Cmd),
                group_name   => register_entry_v1:get_group_name(Cmd),
                version      => Version,
                events       => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
