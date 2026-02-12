%%% @doc vision_refined_v1 event
%%% Emitted when a venture's vision is iteratively refined.
-module(vision_refined_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_venture_id/1, get_brief/1, get_repos/1, get_skills/1,
         get_context_map/1, get_refined_at/1]).

-record(vision_refined_v1, {
    venture_id  :: binary(),
    brief       :: binary() | undefined,
    repos       :: [binary()] | undefined,
    skills      :: [binary()] | undefined,
    context_map :: map() | undefined,
    refined_at  :: integer()
}).

-export_type([vision_refined_v1/0]).
-opaque vision_refined_v1() :: #vision_refined_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> vision_refined_v1().
new(#{venture_id := VentureId} = Params) ->
    #vision_refined_v1{
        venture_id = VentureId,
        brief = maps:get(brief, Params, undefined),
        repos = maps:get(repos, Params, undefined),
        skills = maps:get(skills, Params, undefined),
        context_map = maps:get(context_map, Params, undefined),
        refined_at = erlang:system_time(millisecond)
    }.

-spec to_map(vision_refined_v1()) -> map().
to_map(#vision_refined_v1{} = E) ->
    #{
        <<"event_type">> => <<"vision_refined_v1">>,
        <<"venture_id">> => E#vision_refined_v1.venture_id,
        <<"brief">> => E#vision_refined_v1.brief,
        <<"repos">> => E#vision_refined_v1.repos,
        <<"skills">> => E#vision_refined_v1.skills,
        <<"context_map">> => E#vision_refined_v1.context_map,
        <<"refined_at">> => E#vision_refined_v1.refined_at
    }.

-spec from_map(map()) -> {ok, vision_refined_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #vision_refined_v1{
                venture_id = VentureId,
                brief = get_value(brief, Map, undefined),
                repos = get_value(repos, Map, undefined),
                skills = get_value(skills, Map, undefined),
                context_map = get_value(context_map, Map, undefined),
                refined_at = get_value(refined_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_venture_id(vision_refined_v1()) -> binary().
get_venture_id(#vision_refined_v1{venture_id = V}) -> V.

-spec get_brief(vision_refined_v1()) -> binary() | undefined.
get_brief(#vision_refined_v1{brief = V}) -> V.

-spec get_repos(vision_refined_v1()) -> [binary()] | undefined.
get_repos(#vision_refined_v1{repos = V}) -> V.

-spec get_skills(vision_refined_v1()) -> [binary()] | undefined.
get_skills(#vision_refined_v1{skills = V}) -> V.

-spec get_context_map(vision_refined_v1()) -> map() | undefined.
get_context_map(#vision_refined_v1{context_map = V}) -> V.

-spec get_refined_at(vision_refined_v1()) -> integer().
get_refined_at(#vision_refined_v1{refined_at = V}) -> V.

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
