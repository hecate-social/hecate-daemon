%%% @doc scaffold_venture_repo_v1 command
%%% Scaffolds a venture's git repository with VISION.md and structure.
-module(scaffold_venture_repo_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_repo_path/1, get_brief/1, get_initiated_by/1]).

-record(scaffold_venture_repo_v1, {
    venture_id   :: binary(),
    repo_path    :: binary(),
    brief        :: binary() | undefined,
    initiated_by :: binary() | undefined
}).

-export_type([scaffold_venture_repo_v1/0]).
-opaque scaffold_venture_repo_v1() :: #scaffold_venture_repo_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, scaffold_venture_repo_v1()} | {error, term()}.
new(#{venture_id := VentureId, repo_path := RepoPath} = Params) ->
    {ok, #scaffold_venture_repo_v1{
        venture_id = VentureId,
        repo_path = RepoPath,
        brief = maps:get(brief, Params, undefined),
        initiated_by = maps:get(initiated_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(scaffold_venture_repo_v1()) -> {ok, scaffold_venture_repo_v1()} | {error, term()}.
validate(#scaffold_venture_repo_v1{venture_id = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_venture_id};
validate(#scaffold_venture_repo_v1{repo_path = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_repo_path};
validate(#scaffold_venture_repo_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(scaffold_venture_repo_v1()) -> map().
to_map(#scaffold_venture_repo_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"scaffold_venture_repo">>,
        <<"venture_id">> => Cmd#scaffold_venture_repo_v1.venture_id,
        <<"repo_path">> => Cmd#scaffold_venture_repo_v1.repo_path,
        <<"brief">> => Cmd#scaffold_venture_repo_v1.brief,
        <<"initiated_by">> => Cmd#scaffold_venture_repo_v1.initiated_by
    }.

-spec from_map(map()) -> {ok, scaffold_venture_repo_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    RepoPath = get_value(repo_path, Map),
    case {VentureId, RepoPath} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #scaffold_venture_repo_v1{
                venture_id = VentureId,
                repo_path = RepoPath,
                brief = get_value(brief, Map, undefined),
                initiated_by = get_value(initiated_by, Map, undefined)
            }}
    end.

%% Accessors
-spec get_venture_id(scaffold_venture_repo_v1()) -> binary().
get_venture_id(#scaffold_venture_repo_v1{venture_id = V}) -> V.

-spec get_repo_path(scaffold_venture_repo_v1()) -> binary().
get_repo_path(#scaffold_venture_repo_v1{repo_path = V}) -> V.

-spec get_brief(scaffold_venture_repo_v1()) -> binary() | undefined.
get_brief(#scaffold_venture_repo_v1{brief = V}) -> V.

-spec get_initiated_by(scaffold_venture_repo_v1()) -> binary() | undefined.
get_initiated_by(#scaffold_venture_repo_v1{initiated_by = V}) -> V.

%% Internal
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
