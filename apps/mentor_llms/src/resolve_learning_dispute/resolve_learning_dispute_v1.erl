%%% @doc resolve_learning_dispute_v1 command
%%% Resolves a dispute on a learning.
-module(resolve_learning_dispute_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_learning_id/1, get_resolver_id/1, get_resolution/1]).

-record(resolve_learning_dispute_v1, {
    learning_id :: binary(),
    resolver_id :: binary(),
    resolution  :: binary() | undefined
}).

-export_type([resolve_learning_dispute_v1/0]).
-opaque resolve_learning_dispute_v1() :: #resolve_learning_dispute_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, resolve_learning_dispute_v1()} | {error, term()}.
new(#{learning_id := LId} = Params) ->
    ResolverId = case maps:find(resolver_id, Params) of
        {ok, V} -> V;
        error   -> hecate_identity:agent_id()
    end,
    Cmd = #resolve_learning_dispute_v1{
        learning_id = LId,
        resolver_id = ResolverId,
        resolution = maps:get(resolution, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(resolve_learning_dispute_v1()) -> {ok, resolve_learning_dispute_v1()} | {error, term()}.
validate(#resolve_learning_dispute_v1{learning_id = LId}) when not is_binary(LId) ->
    {error, invalid_learning_id};
validate(#resolve_learning_dispute_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(resolve_learning_dispute_v1()) -> map().
to_map(#resolve_learning_dispute_v1{} = Cmd) ->
    #{
        command_type => <<"resolve_learning_dispute">>,
        learning_id => Cmd#resolve_learning_dispute_v1.learning_id,
        resolver_id => Cmd#resolve_learning_dispute_v1.resolver_id,
        resolution => Cmd#resolve_learning_dispute_v1.resolution
    }.

-spec from_map(map()) -> {ok, resolve_learning_dispute_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_learning_id(#resolve_learning_dispute_v1{learning_id = V}) -> V.
get_resolver_id(#resolve_learning_dispute_v1{resolver_id = V}) -> V.
get_resolution(#resolve_learning_dispute_v1{resolution = V}) -> V.
