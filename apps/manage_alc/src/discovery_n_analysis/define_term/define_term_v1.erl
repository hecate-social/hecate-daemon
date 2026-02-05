%%% @doc define_term_v1 command
%%% Defines a term in the ubiquitous language for a project.
-module(define_term_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1, get_term_id/1, get_term/1, get_definition/1]).

-record(define_term_v1, {
    project_id :: binary(),
    term_id    :: binary(),
    term       :: binary(),
    definition :: binary()
}).

-export_type([define_term_v1/0]).
-opaque define_term_v1() :: #define_term_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, define_term_v1()} | {error, term()}.
new(#{project_id := ProjectId, term := Term, definition := Definition} = Params) ->
    Cmd = #define_term_v1{
        project_id = ProjectId,
        term_id = maps:get(term_id, Params, generate_id()),
        term = Term,
        definition = Definition
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(define_term_v1()) -> {ok, define_term_v1()} | {error, term()}.
validate(#define_term_v1{term = T}) when
    not is_binary(T); byte_size(T) =:= 0 ->
    {error, invalid_term};
validate(#define_term_v1{definition = D}) when
    not is_binary(D); byte_size(D) =:= 0 ->
    {error, invalid_definition};
validate(#define_term_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(define_term_v1()) -> map().
to_map(#define_term_v1{} = Cmd) ->
    #{
        command_type => <<"define_term">>,
        project_id => Cmd#define_term_v1.project_id,
        term_id => Cmd#define_term_v1.term_id,
        term => Cmd#define_term_v1.term,
        definition => Cmd#define_term_v1.definition
    }.

-spec from_map(map()) -> {ok, define_term_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#define_term_v1{project_id = V}) -> V.
get_term_id(#define_term_v1{term_id = V}) -> V.
get_term(#define_term_v1{term = V}) -> V.
get_definition(#define_term_v1{definition = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"trm-", Ts/binary, "-", Rand/binary>>.
