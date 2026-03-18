%%% @doc API handler: GET/PUT/DELETE /api/briefcase/files/:file_id
%%%
%%% GET    - Returns file metadata by ID.
%%% PUT    - Update file metadata (rename, move, star/unstar).
%%% DELETE - Archive a file.
%%% @end
-module(get_file_by_id_api).

-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/briefcase/files/:file_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">>    -> handle_get(Req0, State);
        <<"PUT">>    -> handle_put(Req0, State);
        <<"DELETE">> -> handle_delete(Req0, State);
        _            -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case project_briefcase_store:get_file(FileId) of
        {ok, File} ->
            hecate_api_utils:json_ok(#{file => File}, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0)
    end.

handle_put(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            do_update_file(FileId, Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

handle_delete(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    Now = erlang:system_time(millisecond),
    Payload = #{
        command_type => <<"archive_file">>,
        file_id => FileId,
        archived_at => Now
    },
    case dispatch_file_cmd(FileId, archive_file, Payload) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{archived => true}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.

do_update_file(FileId, Body, Req) ->
    Name = hecate_api_utils:get_field(name, Body),
    FolderId = hecate_api_utils:get_field(folder_id, Body),
    Starred = hecate_api_utils:get_field(starred, Body),
    Now = erlang:system_time(millisecond),
    %% Apply rename if present
    Result1 = case Name of
        undefined -> ok;
        _ ->
            Payload = #{
                command_type => <<"rename_file">>,
                file_id => FileId,
                name => Name,
                renamed_at => Now
            },
            dispatch_file_cmd(FileId, rename_file, Payload)
    end,
    %% Apply move if present (and rename succeeded)
    Result2 = case {Result1, FolderId} of
        {ok, undefined} -> ok;
        {{ok, _, _}, undefined} -> ok;
        {{error, _} = Err, _} -> Err;
        {_, undefined} -> ok;
        {_, _} ->
            MovePayload = #{
                command_type => <<"move_file">>,
                file_id => FileId,
                folder_id => FolderId,
                moved_at => Now
            },
            dispatch_file_cmd(FileId, move_file, MovePayload)
    end,
    %% Apply star/unstar if present (and previous succeeded)
    Result3 = case {Result2, Starred} of
        {ok, undefined} -> ok;
        {{ok, _, _}, undefined} -> ok;
        {{error, _} = Err2, _} -> Err2;
        {_, undefined} -> ok;
        {_, true} ->
            StarPayload = #{
                command_type => <<"star_file">>,
                file_id => FileId,
                starred_at => Now
            },
            dispatch_file_cmd(FileId, star_file, StarPayload);
        {_, false} ->
            UnstarPayload = #{
                command_type => <<"unstar_file">>,
                file_id => FileId,
                unstarred_at => Now
            },
            dispatch_file_cmd(FileId, unstar_file, UnstarPayload);
        {_, _} -> ok
    end,
    case Result3 of
        ok ->
            hecate_api_utils:json_ok(#{updated => true}, Req);
        {ok, _, _} ->
            hecate_api_utils:json_ok(#{updated => true}, Req);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req)
    end.

dispatch_file_cmd(FileId, CmdType, Payload) ->
    EvoqCmd = #evoq_command{
        command_type = CmdType,
        aggregate_type = file_aggregate,
        aggregate_id = FileId,
        payload = Payload,
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
