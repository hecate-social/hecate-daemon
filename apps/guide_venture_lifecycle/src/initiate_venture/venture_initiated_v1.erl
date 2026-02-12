%%% @doc venture_initiated_v1 event
%%% Emitted when a venture is successfully initiated.
-module(venture_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_venture_id/1, get_name/1, get_brief/1, get_repos/1, get_skills/1,
         get_context_map/1, get_initiated_by/1, get_initiated_at/1]).

-record(venture_initiated_v1, {
    venture_id   :: binary(),
    name         :: binary(),
    brief        :: binary() | undefined,
    repos        :: [binary()],
    skills       :: [binary()],
    context_map  :: map(),
    initiated_by :: binary() | undefined,
    initiated_at :: integer()
}).

-export_type([venture_initiated_v1/0]).
-opaque venture_initiated_v1() :: #venture_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> venture_initiated_v1().
new(#{venture_id := VentureId, name := Name} = Params) ->
    #venture_initiated_v1{
        venture_id = VentureId,
        name = Name,
        brief = maps:get(brief, Params, undefined),
        repos = maps:get(repos, Params, []),
        skills = maps:get(skills, Params, []),
        context_map = maps:get(context_map, Params, #{}),
        initiated_by = maps:get(initiated_by, Params, undefined),
        initiated_at = erlang:system_time(millisecond)
    }.

-spec to_map(venture_initiated_v1()) -> map().
to_map(#venture_initiated_v1{} = E) ->
    #{
        <<"event_type">> => <<"venture_initiated_v1">>,
        <<"venture_id">> => E#venture_initiated_v1.venture_id,
        <<"name">> => E#venture_initiated_v1.name,
        <<"brief">> => E#venture_initiated_v1.brief,
        <<"repos">> => E#venture_initiated_v1.repos,
        <<"skills">> => E#venture_initiated_v1.skills,
        <<"context_map">> => E#venture_initiated_v1.context_map,
        <<"initiated_by">> => E#venture_initiated_v1.initiated_by,
        <<"initiated_at">> => E#venture_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, venture_initiated_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    Name = get_value(name, Map),
    case {VentureId, Name} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #venture_initiated_v1{
                venture_id = VentureId,
                name = Name,
                brief = get_value(brief, Map, undefined),
                repos = get_value(repos, Map, []),
                skills = get_value(skills, Map, []),
                context_map = get_value(context_map, Map, #{}),
                initiated_by = get_value(initiated_by, Map, undefined),
                initiated_at = get_value(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_venture_id(venture_initiated_v1()) -> binary().
get_venture_id(#venture_initiated_v1{venture_id = V}) -> V.

-spec get_name(venture_initiated_v1()) -> binary().
get_name(#venture_initiated_v1{name = V}) -> V.

-spec get_brief(venture_initiated_v1()) -> binary() | undefined.
get_brief(#venture_initiated_v1{brief = V}) -> V.

-spec get_repos(venture_initiated_v1()) -> [binary()].
get_repos(#venture_initiated_v1{repos = V}) -> V.

-spec get_skills(venture_initiated_v1()) -> [binary()].
get_skills(#venture_initiated_v1{skills = V}) -> V.

-spec get_context_map(venture_initiated_v1()) -> map().
get_context_map(#venture_initiated_v1{context_map = V}) -> V.

-spec get_initiated_by(venture_initiated_v1()) -> binary() | undefined.
get_initiated_by(#venture_initiated_v1{initiated_by = V}) -> V.

-spec get_initiated_at(venture_initiated_v1()) -> integer().
get_initiated_at(#venture_initiated_v1{initiated_at = V}) -> V.

%% Internal helper to get value with atom or binary key
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
