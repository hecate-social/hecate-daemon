%%% @doc torch_vision_refined_v1 event
%%% Emitted when a torch's vision is iteratively refined during DnA.
-module(torch_vision_refined_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_torch_id/1, get_brief/1, get_repos/1, get_skills/1,
         get_context_map/1, get_refined_by/1, get_refined_at/1]).

-record(torch_vision_refined_v1, {
    torch_id    :: binary(),
    brief       :: binary() | undefined,
    repos       :: [binary()] | undefined,
    skills      :: [binary()] | undefined,
    context_map :: map() | undefined,
    refined_by  :: binary() | undefined,
    refined_at  :: integer()
}).

-export_type([torch_vision_refined_v1/0]).
-opaque torch_vision_refined_v1() :: #torch_vision_refined_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> torch_vision_refined_v1().
new(#{torch_id := TorchId} = Params) ->
    #torch_vision_refined_v1{
        torch_id = TorchId,
        brief = maps:get(brief, Params, undefined),
        repos = maps:get(repos, Params, undefined),
        skills = maps:get(skills, Params, undefined),
        context_map = maps:get(context_map, Params, undefined),
        refined_by = maps:get(refined_by, Params, undefined),
        refined_at = erlang:system_time(millisecond)
    }.

-spec to_map(torch_vision_refined_v1()) -> map().
to_map(#torch_vision_refined_v1{} = E) ->
    #{
        <<"event_type">> => <<"torch_vision_refined_v1">>,
        <<"torch_id">> => E#torch_vision_refined_v1.torch_id,
        <<"brief">> => E#torch_vision_refined_v1.brief,
        <<"repos">> => E#torch_vision_refined_v1.repos,
        <<"skills">> => E#torch_vision_refined_v1.skills,
        <<"context_map">> => E#torch_vision_refined_v1.context_map,
        <<"refined_by">> => E#torch_vision_refined_v1.refined_by,
        <<"refined_at">> => E#torch_vision_refined_v1.refined_at
    }.

-spec from_map(map()) -> {ok, torch_vision_refined_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    case TorchId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #torch_vision_refined_v1{
                torch_id = TorchId,
                brief = get_value(brief, Map, undefined),
                repos = get_value(repos, Map, undefined),
                skills = get_value(skills, Map, undefined),
                context_map = get_value(context_map, Map, undefined),
                refined_by = get_value(refined_by, Map, undefined),
                refined_at = get_value(refined_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_torch_id(torch_vision_refined_v1()) -> binary().
get_torch_id(#torch_vision_refined_v1{torch_id = V}) -> V.

-spec get_brief(torch_vision_refined_v1()) -> binary() | undefined.
get_brief(#torch_vision_refined_v1{brief = V}) -> V.

-spec get_repos(torch_vision_refined_v1()) -> [binary()] | undefined.
get_repos(#torch_vision_refined_v1{repos = V}) -> V.

-spec get_skills(torch_vision_refined_v1()) -> [binary()] | undefined.
get_skills(#torch_vision_refined_v1{skills = V}) -> V.

-spec get_context_map(torch_vision_refined_v1()) -> map() | undefined.
get_context_map(#torch_vision_refined_v1{context_map = V}) -> V.

-spec get_refined_by(torch_vision_refined_v1()) -> binary() | undefined.
get_refined_by(#torch_vision_refined_v1{refined_by = V}) -> V.

-spec get_refined_at(torch_vision_refined_v1()) -> integer().
get_refined_at(#torch_vision_refined_v1{refined_at = V}) -> V.

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
