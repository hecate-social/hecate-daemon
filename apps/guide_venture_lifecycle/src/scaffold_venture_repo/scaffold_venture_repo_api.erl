%%% @doc API handler: POST /api/ventures/:venture_id/scaffold
%%%
%%% Two-phase handler:
%%% Phase 1 — Filesystem: Create repo directory, write VISION.md, git init
%%% Phase 2 — Event: Dispatch scaffold command → venture_repo_scaffolded_v1
%%%
%%% Vision content is written to disk but NOT stored in the event.
%%% @end
-module(scaffold_venture_repo_api).

-include("venture_lifecycle_status.hrl").

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            VentureId = cowboy_req:binding(venture_id, Req1),
            do_scaffold(VentureId, Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_scaffold(VentureId, Params, Req) ->
    RepoPath = hecate_api_utils:get_field(repo_path, Params),
    VisionContent = hecate_api_utils:get_field(vision_content, Params),
    VentureName = hecate_api_utils:get_field(venture_name, Params),
    Brief = hecate_api_utils:get_field(brief, Params),

    case validate(RepoPath) of
        ok ->
            case scaffold_filesystem(RepoPath, VentureId, VentureName, VisionContent) of
                ok ->
                    dispatch_event(VentureId, RepoPath, Brief, Req);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined) -> {error, <<"repo_path is required">>};
validate(RepoPath) when not is_binary(RepoPath); byte_size(RepoPath) =:= 0 ->
    {error, <<"repo_path must be a non-empty string">>};
validate(RepoPath) ->
    %% Expand ~ to home dir
    Path = expand_path(RepoPath),
    case filelib:is_dir(Path) of
        true -> {error, <<"repo_path already exists">>};
        false -> ok
    end.

%% Phase 1: Filesystem scaffolding
scaffold_filesystem(RepoPath, VentureId, VentureName, VisionContent) ->
    Path = expand_path(RepoPath),
    Name = case VentureName of
        undefined -> <<"venture">>;
        N -> N
    end,
    try
        ok = filelib:ensure_dir(filename:join(Path, ".")),
        ok = ensure_dir(Path),
        ok = ensure_dir(filename:join(Path, ".hecate")),
        ok = ensure_dir(filename:join(Path, "divisions")),

        %% .hecate/venture.json
        VentureJson = json:encode(#{
            <<"venture_id">> => VentureId,
            <<"name">> => Name,
            <<"scaffolded_at">> => erlang:system_time(millisecond)
        }),
        ok = file:write_file(filename:join([Path, ".hecate", "venture.json"]), VentureJson),

        %% VISION.md
        Vision = case VisionContent of
            undefined -> <<"# ", Name/binary, " \u2014 Vision\n\n(No vision document yet)\n">>;
            V -> V
        end,
        ok = file:write_file(filename:join(Path, "VISION.md"), Vision),

        %% README.md
        Readme = <<"# ", Name/binary, "\n\nScaffolded by Hecate.\n\nSee [VISION.md](VISION.md) for the venture vision.\n">>,
        ok = file:write_file(filename:join(Path, "README.md"), Readme),

        %% CHANGELOG.md
        Changelog = <<"# Changelog\n\n## [Unreleased]\n\n- Venture scaffolded\n">>,
        ok = file:write_file(filename:join(Path, "CHANGELOG.md"), Changelog),

        %% .gitignore
        Gitignore = <<"# OS\n.DS_Store\nThumbs.db\n\n# IDE\n.idea/\n.vscode/\n*.swp\n*.swo\n\n# Build\n_build/\ndeps/\nnode_modules/\n">>,
        ok = file:write_file(filename:join(Path, ".gitignore"), Gitignore),

        %% git init + commit
        PathStr = binary_to_list(Path),
        _ = os:cmd("git -C " ++ shell_quote(PathStr) ++ " init"),
        _ = os:cmd("git -C " ++ shell_quote(PathStr) ++ " add -A"),
        _ = os:cmd("git -C " ++ shell_quote(PathStr) ++ " commit -m \"Venture scaffolded by Hecate\""),
        ok
    catch
        _:Reason ->
            logger:error("[scaffold_venture_repo_api] filesystem error: ~p", [Reason]),
            {error, iolist_to_binary(io_lib:format("Filesystem error: ~p", [Reason]))}
    end.

%% Phase 2: Dispatch event via evoq
dispatch_event(VentureId, RepoPath, Brief, Req) ->
    CmdParams = #{
        venture_id => VentureId,
        repo_path => expand_path(RepoPath),
        brief => Brief,
        initiated_by => <<"hecate-web">>
    },
    case scaffold_venture_repo_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_scaffold_venture_repo:dispatch(Cmd) of
                {ok, Version, EventMaps} ->
                    hecate_api_utils:json_ok(200, #{
                        <<"ok">> => true,
                        <<"repo_path">> => expand_path(RepoPath),
                        <<"version">> => Version,
                        <<"events">> => EventMaps
                    }, Req);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

%% Helpers

%% Like file:make_dir/1 but treats eexist as success
ensure_dir(Dir) ->
    case file:make_dir(Dir) of
        ok -> ok;
        {error, eexist} -> ok;
        {error, Reason} -> {error, Reason}
    end.

expand_path(<<"~/", Rest/binary>>) ->
    Home = list_to_binary(os:getenv("HOME")),
    <<Home/binary, "/", Rest/binary>>;
expand_path(Path) ->
    Path.

shell_quote(Str) ->
    "'" ++ lists:flatmap(fun($') -> "'\\''"; (C) -> [C] end, Str) ++ "'".
