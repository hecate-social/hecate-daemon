%%% @doc YAML read/write for sidebar group configuration.
%%%
%%% Reads and writes ~/.hecate/config/sidebar.yaml.
%%% Pure functions -- no gen_server, no state.
%%% @end
-module(sidebar_config).

-export([read/0, write/1]).

-spec read() -> {ok, [map()]} | {error, term()}.
read() ->
    Path = shared_paths:config_path("sidebar.yaml"),
    case filelib:is_regular(Path) of
        false ->
            {ok, []};
        true ->
            try
                [Doc | _] = yamerl:decode_file(Path),
                Groups = parse_groups(Doc),
                {ok, Groups}
            catch
                _:Reason ->
                    {error, Reason}
            end
    end.

-spec write([map()]) -> ok | {error, term()}.
write(Groups) when is_list(Groups) ->
    Path = shared_paths:config_path("sidebar.yaml"),
    ok = filelib:ensure_path(shared_paths:config_dir()),
    Yaml = groups_to_yaml(Groups),
    TmpPath = Path ++ ".tmp",
    case file:write_file(TmpPath, Yaml) of
        ok ->
            file:rename(TmpPath, Path);
        {error, _} = Err ->
            Err
    end.

%%% Internal — YAML parsing

parse_groups(Doc) ->
    case proplists:get_value("groups", Doc, []) of
        Groups when is_list(Groups) ->
            [parse_group(G) || G <- Groups];
        _ ->
            []
    end.

parse_group(Props) when is_list(Props) ->
    #{
        name => to_bin(proplists:get_value("name", Props, "")),
        icon => to_bin(proplists:get_value("icon", Props, "\xF0\x9F\x93\x81")),
        collapsed => proplists:get_value("collapsed", Props, false) =:= true,
        apps => [to_bin(A) || A <- proplists:get_value("apps", Props, []),
                              is_list(A) orelse is_binary(A)]
    };
parse_group(_) ->
    #{name => <<>>, icon => <<"\xF0\x9F\x93\x81">>, collapsed => false, apps => []}.

to_bin(V) when is_binary(V) -> V;
to_bin(V) when is_list(V) -> unicode:characters_to_binary(V);
to_bin(V) when is_atom(V) -> atom_to_binary(V, utf8);
to_bin(_) -> <<>>.

%%% Internal — YAML generation

groups_to_yaml(Groups) ->
    Header = <<"# Sidebar group configuration for hecate-web\n"
               "# Groups organize plugins in the sidebar. "
               "Plugins not in any group appear under \"Ungrouped\".\n"
               "groups:\n">>,
    Body = iolist_to_binary([group_to_yaml(G) || G <- Groups]),
    <<Header/binary, Body/binary>>.

group_to_yaml(#{name := Name, icon := Icon, collapsed := Collapsed, apps := Apps}) ->
    CollStr = case Collapsed of true -> <<"true">>; false -> <<"false">> end,
    NameBin = to_bin(Name),
    IconBin = to_bin(Icon),
    AppsYaml = case Apps of
        [] -> <<"    apps: []\n">>;
        _ -> iolist_to_binary([
            <<"    apps:\n">>,
            [[<<"      - ">>, to_bin(A), <<"\n">>] || A <- Apps]
        ])
    end,
    <<"  - name: \"", NameBin/binary, "\"\n"
      "    icon: \"", IconBin/binary, "\"\n"
      "    collapsed: ", CollStr/binary, "\n",
      AppsYaml/binary>>;
group_to_yaml(_) ->
    <<>>.
