%%% @doc API handler: GET/POST /api/briefcase/folders
%%%
%%% GET  - Returns all folders from the briefcase folder tree.
%%% POST - Creates a new folder via the briefcase aggregate.
%%% @end
-module(get_folders_tree_api).

-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/briefcase/folders", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">>  -> handle_get(Req0, State);
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Folders = project_briefcase_store:list_folders(),
    hecate_api_utils:json_ok(#{folders => Folders}, Req0).

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            do_create_folder(Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_create_folder(Body, Req) ->
    Name = hecate_api_utils:get_field(name, Body),
    case Name of
        undefined ->
            hecate_api_utils:bad_request(<<"name is required">>, Req);
        _ ->
            FolderId = generate_folder_id(),
            ParentId = hecate_api_utils:get_field(parent_id, Body),
            Icon = hecate_api_utils:get_field(icon, Body),
            Now = erlang:system_time(millisecond),
            Payload = #{
                command_type => <<"create_folder">>,
                folder_id => FolderId,
                name => Name,
                parent_id => ParentId,
                icon => Icon,
                created_at => Now
            },
            EvoqCmd = #evoq_command{
                command_type = create_folder,
                aggregate_type = folder_aggregate,
                aggregate_id = FolderId,
                payload = Payload,
                metadata = #{timestamp => Now}
            },
            case evoq_dispatcher:dispatch(EvoqCmd, dispatch_opts()) of
                {ok, _Version, _Events} ->
                    hecate_api_utils:json_ok(201, #{ok => true, folder_id => FolderId}, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req)
            end
    end.

generate_folder_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Hex = binary:encode_hex(crypto:strong_rand_bytes(2)),
    <<"folder-", Ts/binary, "-", Hex/binary>>.

dispatch_opts() ->
    #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }.
