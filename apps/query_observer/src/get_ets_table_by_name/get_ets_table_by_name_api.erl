%%% @doc GET /api/observer/ets/:name — ETS table content browser.
%%%
%%% Paginated contents of a named ETS table.
%%% Terms serialized safely with depth-limited formatting.
%%% Large binaries (>1KB) are truncated.
%%% @end
-module(get_ets_table_by_name_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/ets/:name", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    NameBin = cowboy_req:binding(name, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Limit = qs_int(<<"limit">>, QS, 50),
    Offset = qs_int(<<"offset">>, QS, 0),
    case find_table(NameBin) of
        {ok, Tab} ->
            Size = ets:info(Tab, size),
            %% For small tables, use tab2list; for large, use match
            AllRows = case Size =< 1000 of
                true -> ets:tab2list(Tab);
                false -> ets:tab2list(Tab)  %% TODO: use continuation for very large tables
            end,
            Page = lists:sublist(safe_drop(AllRows, Offset), Limit),
            Items = [format_row(Row) || Row <- Page],
            TableInfo = #{
                name => NameBin,
                type => atom_to_binary(ets:info(Tab, type)),
                size => Size,
                protection => atom_to_binary(ets:info(Tab, protection))
            },
            hecate_api_utils:json_ok(#{items => Items, total => Size,
                                       limit => Limit, offset => Offset,
                                       table => TableInfo}, Req0);
        not_found ->
            hecate_api_utils:not_found(Req0)
    end.

find_table(NameBin) ->
    try
        Name = binary_to_existing_atom(NameBin),
        case ets:info(Name) of
            undefined -> not_found;
            _ -> {ok, Name}
        end
    catch _:_ -> not_found
    end.

format_row(Tuple) when is_tuple(Tuple) ->
    Elements = tuple_to_list(Tuple),
    case Elements of
        [Key | Values] ->
            #{key => format_term(Key),
              values => [format_term(V) || V <- Values]};
        [] ->
            #{key => <<"()">>, values => []}
    end;
format_row(Other) ->
    #{key => format_term(Other), values => []}.

format_term(Term) ->
    term_to_json(Term, 10).

%% Structured JSON serialization of Erlang terms.
%% Produces navigable JSON instead of flat text.
term_to_json(undefined, _) -> null;
term_to_json(null, _) -> null;
term_to_json(true, _) -> true;
term_to_json(false, _) -> false;
term_to_json(N, _) when is_integer(N) -> N;
term_to_json(N, _) when is_float(N) -> N;
term_to_json(A, _) when is_atom(A) ->
    #{<<"__type">> => <<"atom">>, <<"value">> => atom_to_binary(A)};
term_to_json(Bin, _) when is_binary(Bin), byte_size(Bin) > 1024 ->
    Truncated = binary:part(Bin, 0, 1024),
    #{<<"__type">> => <<"binary">>,
      <<"value">> => Truncated,
      <<"truncated">> => true,
      <<"size">> => byte_size(Bin)};
term_to_json(Bin, _) when is_binary(Bin) -> Bin;
term_to_json(Pid, _) when is_pid(Pid) ->
    #{<<"__type">> => <<"pid">>, <<"value">> => list_to_binary(pid_to_list(Pid))};
term_to_json(Ref, _) when is_reference(Ref) ->
    #{<<"__type">> => <<"ref">>, <<"value">> => list_to_binary(ref_to_list(Ref))};
term_to_json(Fun, _) when is_function(Fun) ->
    #{<<"__type">> => <<"fun">>, <<"value">> => list_to_binary(erlang:fun_to_list(Fun))};
term_to_json(Map, Depth) when is_map(Map), Depth > 0 ->
    #{<<"__type">> => <<"map">>,
      <<"entries">> => maps:fold(fun(K, V, Acc) ->
          [#{<<"k">> => term_to_json(K, Depth - 1),
             <<"v">> => term_to_json(V, Depth - 1)} | Acc]
      end, [], Map)};
term_to_json(List, Depth) when is_list(List), Depth > 0 ->
    case io_lib:printable_unicode_list(List) of
        true -> unicode:characters_to_binary(List);
        false -> [term_to_json(E, Depth - 1) || E <- List]
    end;
term_to_json(Tuple, Depth) when is_tuple(Tuple), Depth > 0 ->
    #{<<"__type">> => <<"tuple">>,
      <<"elements">> => [term_to_json(E, Depth - 1) || E <- tuple_to_list(Tuple)]};
term_to_json(Term, _) ->
    iolist_to_binary(io_lib:format("~P", [Term, 8])).

qs_int(Key, QS, Default) ->
    case proplists:get_value(Key, QS) of
        undefined -> Default;
        Bin -> binary_to_integer(Bin)
    end.

safe_drop(List, 0) -> List;
safe_drop(List, N) when N >= length(List) -> [];
safe_drop(List, N) -> lists:nthtail(N, List).
