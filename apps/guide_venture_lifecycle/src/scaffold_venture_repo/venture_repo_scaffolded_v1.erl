%%% @doc venture_repo_scaffolded_v1 event
%%% Emitted when a venture repository is successfully scaffolded.
%%% Payload is small — only path and brief, not VISION.md content.
-module(venture_repo_scaffolded_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_venture_id/1, get_repo_path/1, get_brief/1, get_scaffolded_at/1]).

-record(venture_repo_scaffolded_v1, {
    venture_id    :: binary(),
    repo_path     :: binary(),
    brief         :: binary() | undefined,
    scaffolded_at :: integer()
}).

-export_type([venture_repo_scaffolded_v1/0]).
-opaque venture_repo_scaffolded_v1() :: #venture_repo_scaffolded_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> venture_repo_scaffolded_v1().
new(#{venture_id := VentureId, repo_path := RepoPath} = Params) ->
    #venture_repo_scaffolded_v1{
        venture_id = VentureId,
        repo_path = RepoPath,
        brief = maps:get(brief, Params, undefined),
        scaffolded_at = erlang:system_time(millisecond)
    }.

-spec to_map(venture_repo_scaffolded_v1()) -> map().
to_map(#venture_repo_scaffolded_v1{} = E) ->
    #{
        <<"event_type">> => <<"venture_repo_scaffolded_v1">>,
        <<"venture_id">> => E#venture_repo_scaffolded_v1.venture_id,
        <<"repo_path">> => E#venture_repo_scaffolded_v1.repo_path,
        <<"brief">> => E#venture_repo_scaffolded_v1.brief,
        <<"scaffolded_at">> => E#venture_repo_scaffolded_v1.scaffolded_at
    }.

-spec from_map(map()) -> {ok, venture_repo_scaffolded_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    RepoPath = get_value(repo_path, Map),
    case {VentureId, RepoPath} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #venture_repo_scaffolded_v1{
                venture_id = VentureId,
                repo_path = RepoPath,
                brief = get_value(brief, Map, undefined),
                scaffolded_at = get_value(scaffolded_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_venture_id(venture_repo_scaffolded_v1()) -> binary().
get_venture_id(#venture_repo_scaffolded_v1{venture_id = V}) -> V.

-spec get_repo_path(venture_repo_scaffolded_v1()) -> binary().
get_repo_path(#venture_repo_scaffolded_v1{repo_path = V}) -> V.

-spec get_brief(venture_repo_scaffolded_v1()) -> binary() | undefined.
get_brief(#venture_repo_scaffolded_v1{brief = V}) -> V.

-spec get_scaffolded_at(venture_repo_scaffolded_v1()) -> integer().
get_scaffolded_at(#venture_repo_scaffolded_v1{scaffolded_at = V}) -> V.

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
