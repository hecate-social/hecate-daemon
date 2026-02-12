%%% @doc refine_vision_v1 command
%%% Iteratively updates venture vision fields during setup.
%%% All fields optional except venture_id — partial updates only.
-module(refine_vision_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_brief/1, get_repos/1, get_skills/1,
         get_context_map/1]).

-record(refine_vision_v1, {
    venture_id  :: binary(),
    brief       :: binary() | undefined,
    repos       :: [binary()] | undefined,
    skills      :: [binary()] | undefined,
    context_map :: map() | undefined
}).

-export_type([refine_vision_v1/0]).
-opaque refine_vision_v1() :: #refine_vision_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, refine_vision_v1()} | {error, term()}.
new(#{venture_id := VentureId} = Params) ->
    {ok, #refine_vision_v1{
        venture_id = VentureId,
        brief = maps:get(brief, Params, undefined),
        repos = maps:get(repos, Params, undefined),
        skills = maps:get(skills, Params, undefined),
        context_map = maps:get(context_map, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(refine_vision_v1()) -> {ok, refine_vision_v1()} | {error, term()}.
validate(#refine_vision_v1{venture_id = VentureId}) when
    not is_binary(VentureId); byte_size(VentureId) =:= 0 ->
    {error, invalid_venture_id};
validate(#refine_vision_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(refine_vision_v1()) -> map().
to_map(#refine_vision_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"refine_vision">>,
        <<"venture_id">> => Cmd#refine_vision_v1.venture_id,
        <<"brief">> => Cmd#refine_vision_v1.brief,
        <<"repos">> => Cmd#refine_vision_v1.repos,
        <<"skills">> => Cmd#refine_vision_v1.skills,
        <<"context_map">> => Cmd#refine_vision_v1.context_map
    }.

-spec from_map(map()) -> {ok, refine_vision_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #refine_vision_v1{
                venture_id = VentureId,
                brief = get_value(brief, Map, undefined),
                repos = get_value(repos, Map, undefined),
                skills = get_value(skills, Map, undefined),
                context_map = get_value(context_map, Map, undefined)
            }}
    end.

%% Accessors
-spec get_venture_id(refine_vision_v1()) -> binary().
get_venture_id(#refine_vision_v1{venture_id = V}) -> V.

-spec get_brief(refine_vision_v1()) -> binary() | undefined.
get_brief(#refine_vision_v1{brief = V}) -> V.

-spec get_repos(refine_vision_v1()) -> [binary()] | undefined.
get_repos(#refine_vision_v1{repos = V}) -> V.

-spec get_skills(refine_vision_v1()) -> [binary()] | undefined.
get_skills(#refine_vision_v1{skills = V}) -> V.

-spec get_context_map(refine_vision_v1()) -> map() | undefined.
get_context_map(#refine_vision_v1{context_map = V}) -> V.

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
