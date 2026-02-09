%%% @doc refine_vision_v1 command
%%% Iteratively updates torch vision fields during DnA phase.
%%% All fields optional except torch_id — partial updates only.
-module(refine_vision_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_torch_id/1, get_brief/1, get_repos/1, get_skills/1,
         get_context_map/1, get_refined_by/1]).

-record(refine_vision_v1, {
    torch_id    :: binary(),
    brief       :: binary() | undefined,
    repos       :: [binary()] | undefined,
    skills      :: [binary()] | undefined,
    context_map :: map() | undefined,
    refined_by  :: binary() | undefined
}).

-export_type([refine_vision_v1/0]).
-opaque refine_vision_v1() :: #refine_vision_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, refine_vision_v1()} | {error, term()}.
new(#{torch_id := TorchId} = Params) ->
    {ok, #refine_vision_v1{
        torch_id = TorchId,
        brief = maps:get(brief, Params, undefined),
        repos = maps:get(repos, Params, undefined),
        skills = maps:get(skills, Params, undefined),
        context_map = maps:get(context_map, Params, undefined),
        refined_by = maps:get(refined_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(refine_vision_v1()) -> {ok, refine_vision_v1()} | {error, term()}.
validate(#refine_vision_v1{torch_id = TorchId}) when
    not is_binary(TorchId); byte_size(TorchId) =:= 0 ->
    {error, invalid_torch_id};
validate(#refine_vision_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(refine_vision_v1()) -> map().
to_map(#refine_vision_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"refine_vision">>,
        <<"torch_id">> => Cmd#refine_vision_v1.torch_id,
        <<"brief">> => Cmd#refine_vision_v1.brief,
        <<"repos">> => Cmd#refine_vision_v1.repos,
        <<"skills">> => Cmd#refine_vision_v1.skills,
        <<"context_map">> => Cmd#refine_vision_v1.context_map,
        <<"refined_by">> => Cmd#refine_vision_v1.refined_by
    }.

-spec from_map(map()) -> {ok, refine_vision_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    case TorchId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #refine_vision_v1{
                torch_id = TorchId,
                brief = get_value(brief, Map, undefined),
                repos = get_value(repos, Map, undefined),
                skills = get_value(skills, Map, undefined),
                context_map = get_value(context_map, Map, undefined),
                refined_by = get_value(refined_by, Map, undefined)
            }}
    end.

%% Accessors
-spec get_torch_id(refine_vision_v1()) -> binary().
get_torch_id(#refine_vision_v1{torch_id = V}) -> V.

-spec get_brief(refine_vision_v1()) -> binary() | undefined.
get_brief(#refine_vision_v1{brief = V}) -> V.

-spec get_repos(refine_vision_v1()) -> [binary()] | undefined.
get_repos(#refine_vision_v1{repos = V}) -> V.

-spec get_skills(refine_vision_v1()) -> [binary()] | undefined.
get_skills(#refine_vision_v1{skills = V}) -> V.

-spec get_context_map(refine_vision_v1()) -> map() | undefined.
get_context_map(#refine_vision_v1{context_map = V}) -> V.

-spec get_refined_by(refine_vision_v1()) -> binary() | undefined.
get_refined_by(#refine_vision_v1{refined_by = V}) -> V.

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
