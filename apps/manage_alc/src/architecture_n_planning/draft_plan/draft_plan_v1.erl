%%% @doc draft_plan_v1 command
%%% Drafts a plan during the architecture and planning phase.
-module(draft_plan_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1, get_plan_id/1, get_title/1, get_content_ref/1]).

-record(draft_plan_v1, {
    project_id  :: binary(),
    plan_id     :: binary(),
    title       :: binary(),
    content_ref :: binary() | undefined
}).

-export_type([draft_plan_v1/0]).
-opaque draft_plan_v1() :: #draft_plan_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, draft_plan_v1()} | {error, term()}.
new(#{project_id := ProjectId, title := Title} = Params) ->
    Cmd = #draft_plan_v1{
        project_id = ProjectId,
        plan_id = maps:get(plan_id, Params, generate_id()),
        title = Title,
        content_ref = maps:get(content_ref, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(draft_plan_v1()) -> {ok, draft_plan_v1()} | {error, term()}.
validate(#draft_plan_v1{project_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_project_id};
validate(#draft_plan_v1{title = T}) when
    not is_binary(T); byte_size(T) =:= 0 ->
    {error, invalid_title};
validate(#draft_plan_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(draft_plan_v1()) -> map().
to_map(#draft_plan_v1{} = Cmd) ->
    #{
        command_type => <<"draft_plan">>,
        project_id => Cmd#draft_plan_v1.project_id,
        plan_id => Cmd#draft_plan_v1.plan_id,
        title => Cmd#draft_plan_v1.title,
        content_ref => Cmd#draft_plan_v1.content_ref
    }.

-spec from_map(map()) -> {ok, draft_plan_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#draft_plan_v1{project_id = V}) -> V.
get_plan_id(#draft_plan_v1{plan_id = V}) -> V.
get_title(#draft_plan_v1{title = V}) -> V.
get_content_ref(#draft_plan_v1{content_ref = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"pln-", Ts/binary, "-", Rand/binary>>.
