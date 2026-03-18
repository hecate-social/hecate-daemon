%%% @doc API handler: GET/PUT/DELETE /api/briefcase/folders/:folder_id
%%%
%%% GET    - Returns a single folder by ID.
%%% PUT    - Rename or move a folder.
%%% DELETE - Archive a folder.
%%% @end
-module(get_folder_by_id_api).

-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/briefcase/folders/:folder_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">>    -> handle_get(Req0, State);
        <<"PUT">>    -> handle_put(Req0, State);
        <<"DELETE">> -> handle_delete(Req0, State);
        _            -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    FolderId = cowboy_req:binding(folder_id, Req0),
    case project_briefcase_store:get_folder(FolderId) of
        {ok, Folder} ->
            hecate_api_utils:json_ok(#{folder => Folder}, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0)
    end.

handle_put(Req0, _State) ->
    FolderId = cowboy_req:binding(folder_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            do_update_folder(FolderId, Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

handle_delete(Req0, _State) ->
    FolderId = cowboy_req:binding(folder_id, Req0),
    Now = erlang:system_time(millisecond),
    Payload = #{
        command_type => <<"archive_folder">>,
        folder_id => FolderId,
        archived_at => Now
    },
    case dispatch_folder_cmd(FolderId, archive_folder, Payload) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{archived => true}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.

do_update_folder(FolderId, Body, Req) ->
    Name = hecate_api_utils:get_field(name, Body),
    ParentId = hecate_api_utils:get_field(parent_id, Body),
    Now = erlang:system_time(millisecond),
    case {Name, ParentId} of
        {undefined, undefined} ->
            hecate_api_utils:bad_request(<<"name or parent_id required">>, Req);
        {_, undefined} ->
            %% Rename only
            Payload = #{
                command_type => <<"rename_folder">>,
                folder_id => FolderId,
                name => Name,
                renamed_at => Now
            },
            dispatch_and_reply(FolderId, rename_folder, Payload, Req);
        {undefined, _} ->
            %% Move only
            Payload = #{
                command_type => <<"move_folder">>,
                folder_id => FolderId,
                parent_id => ParentId,
                moved_at => Now
            },
            dispatch_and_reply(FolderId, move_folder, Payload, Req);
        {_, _} ->
            %% Rename first, then move
            RenamePayload = #{
                command_type => <<"rename_folder">>,
                folder_id => FolderId,
                name => Name,
                renamed_at => Now
            },
            case dispatch_folder_cmd(FolderId, rename_folder, RenamePayload) of
                {ok, _, _} ->
                    MovePayload = #{
                        command_type => <<"move_folder">>,
                        folder_id => FolderId,
                        parent_id => ParentId,
                        moved_at => Now
                    },
                    dispatch_and_reply(FolderId, move_folder, MovePayload, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req)
            end
    end.

dispatch_and_reply(FolderId, CmdType, Payload, Req) ->
    case dispatch_folder_cmd(FolderId, CmdType, Payload) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{updated => true}, Req);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req)
    end.

dispatch_folder_cmd(FolderId, CmdType, Payload) ->
    EvoqCmd = #evoq_command{
        command_type = CmdType,
        aggregate_type = folder_aggregate,
        aggregate_id = FolderId,
        payload = Payload,
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
