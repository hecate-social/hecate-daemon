%%% @doc venture_vision_refined_v1 event
%%% Emitted when a venture's vision is iteratively refined during setup.
-module(venture_vision_refined_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_venture_id/1, get_brief/1, get_repos/1, get_skills/1,
         get_context_map/1, get_refined_by/1, get_refined_at/1]).

-record(venture_vision_refined_v1, {
    venture_id  :: binary(),
    brief       :: binary() | undefined,
    repos       :: [binary()] | undefined,
    skills      :: [binary()] | undefined,
    context_map :: map() | undefined,
    refined_by  :: binary() | undefined,
    refined_at  :: integer()
}).

-export_type([venture_vision_refined_v1/0]).
-opaque venture_vision_refined_v1() :: #venture_vision_refined_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> venture_vision_refined_v1().
new(#{venture_id := VentureId} = Params) ->
    #venture_vision_refined_v1{
        venture_id = VentureId,
        brief = maps:get(brief, Params, undefined),
        repos = maps:get(repos, Params, undefined),
        skills = maps:get(skills, Params, undefined),
        context_map = maps:get(context_map, Params, undefined),
        refined_by = maps:get(refined_by, Params, undefined),
        refined_at = erlang:system_time(millisecond)
    }.

-spec to_map(venture_vision_refined_v1()) -> map().
to_map(#venture_vision_refined_v1{} = E) ->
    #{
        <<"event_type">> => <<"venture_vision_refined_v1">>,
        <<"venture_id">> => E#venture_vision_refined_v1.venture_id,
        <<"brief">> => E#venture_vision_refined_v1.brief,
        <<"repos">> => E#venture_vision_refined_v1.repos,
        <<"skills">> => E#venture_vision_refined_v1.skills,
        <<"context_map">> => E#venture_vision_refined_v1.context_map,
        <<"refined_by">> => E#venture_vision_refined_v1.refined_by,
        <<"refined_at">> => E#venture_vision_refined_v1.refined_at
    }.

-spec from_map(map()) -> {ok, venture_vision_refined_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #venture_vision_refined_v1{
                venture_id = VentureId,
                brief = get_value(brief, Map, undefined),
                repos = get_value(repos, Map, undefined),
                skills = get_value(skills, Map, undefined),
                context_map = get_value(context_map, Map, undefined),
                refined_by = get_value(refined_by, Map, undefined),
                refined_at = get_value(refined_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_venture_id(venture_vision_refined_v1()) -> binary().
get_venture_id(#venture_vision_refined_v1{venture_id = V}) -> V.

-spec get_brief(venture_vision_refined_v1()) -> binary() | undefined.
get_brief(#venture_vision_refined_v1{brief = V}) -> V.

-spec get_repos(venture_vision_refined_v1()) -> [binary()] | undefined.
get_repos(#venture_vision_refined_v1{repos = V}) -> V.

-spec get_skills(venture_vision_refined_v1()) -> [binary()] | undefined.
get_skills(#venture_vision_refined_v1{skills = V}) -> V.

-spec get_context_map(venture_vision_refined_v1()) -> map() | undefined.
get_context_map(#venture_vision_refined_v1{context_map = V}) -> V.

-spec get_refined_by(venture_vision_refined_v1()) -> binary() | undefined.
get_refined_by(#venture_vision_refined_v1{refined_by = V}) -> V.

-spec get_refined_at(venture_vision_refined_v1()) -> integer().
get_refined_at(#venture_vision_refined_v1{refined_at = V}) -> V.

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
