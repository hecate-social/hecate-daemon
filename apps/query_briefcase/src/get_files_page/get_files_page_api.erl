%%% @doc API handler: GET/POST /api/briefcase/files
%%%
%%% GET  - List files with optional filters (folder_id, starred, search, file_type).
%%% POST - Register a plugin-owned file (no blob).
%%% @end
-module(get_files_page_api).

-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/briefcase/files", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">>  -> handle_get(Req0, State);
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    Files = project_briefcase_store:list_files(Filters),
    hecate_api_utils:json_ok(#{files => Files, total => length(Files)}, Req0).

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            do_register_file(Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_register_file(Body, Req) ->
    Name = hecate_api_utils:get_field(name, Body),
    FileType = hecate_api_utils:get_field(file_type, Body),
    case {Name, FileType} of
        {undefined, _} ->
            hecate_api_utils:bad_request(<<"name is required">>, Req);
        {_, undefined} ->
            hecate_api_utils:bad_request(<<"file_type is required">>, Req);
        _ ->
            FileId = generate_file_id(),
            Plugin = hecate_api_utils:get_field(plugin, Body),
            FolderId = hecate_api_utils:get_field(folder_id, Body),
            Icon = hecate_api_utils:get_field(icon, Body),
            Now = erlang:system_time(millisecond),
            Payload = #{
                command_type => <<"register_file">>,
                file_id => FileId,
                name => Name,
                file_type => FileType,
                plugin => Plugin,
                folder_id => FolderId,
                icon => Icon,
                created_at => Now
            },
            EvoqCmd = #evoq_command{
                command_type = register_file,
                aggregate_type = file_aggregate,
                aggregate_id = FileId,
                payload = Payload,
                metadata = #{timestamp => Now}
            },
            case evoq_dispatcher:dispatch(EvoqCmd, dispatch_opts()) of
                {ok, _Version, _Events} ->
                    hecate_api_utils:json_ok(201, #{ok => true, file_id => FileId}, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req)
            end
    end.

build_filters(QS) ->
    lists:foldl(fun build_filter/2, #{}, QS).

build_filter({<<"folder_id">>, Value}, Acc) ->
    Acc#{folder_id => Value};
build_filter({<<"starred">>, <<"true">>}, Acc) ->
    Acc#{starred => true};
build_filter({<<"search">>, Value}, Acc) when Value =/= <<>> ->
    Acc#{search => Value};
build_filter({<<"file_type">>, Value}, Acc) when Value =/= <<>> ->
    Acc#{file_type => Value};
build_filter(_, Acc) ->
    Acc.

generate_file_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Hex = binary:encode_hex(crypto:strong_rand_bytes(2)),
    <<"file-", Ts/binary, "-", Hex/binary>>.

dispatch_opts() ->
    #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }.
