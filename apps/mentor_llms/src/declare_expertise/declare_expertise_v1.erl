%%% @doc declare_expertise_v1 command
%%% Declares expertise domains for an agent (self-declaration, no gatekeeping).
-module(declare_expertise_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_agent_id/1, get_domains/1]).

-record(declare_expertise_v1, {
    agent_id :: binary(),
    domains  :: [binary()]
}).

-export_type([declare_expertise_v1/0]).
-opaque declare_expertise_v1() :: #declare_expertise_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, declare_expertise_v1()} | {error, term()}.
new(#{domains := Domains} = Params) when is_list(Domains), length(Domains) > 0 ->
    AgentId = case maps:find(agent_id, Params) of
        {ok, V} -> V;
        error   -> hecate_identity:agent_id()
    end,
    Cmd = #declare_expertise_v1{
        agent_id = AgentId,
        domains = Domains
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(declare_expertise_v1()) -> {ok, declare_expertise_v1()} | {error, term()}.
validate(#declare_expertise_v1{agent_id = AId}) when not is_binary(AId) ->
    {error, invalid_agent_id};
validate(#declare_expertise_v1{domains = Domains} = Cmd) ->
    case lists:all(fun is_binary/1, Domains) of
        true -> {ok, Cmd};
        false -> {error, invalid_domains}
    end.

-spec to_map(declare_expertise_v1()) -> map().
to_map(#declare_expertise_v1{} = Cmd) ->
    #{
        command_type => <<"declare_expertise">>,
        agent_id => Cmd#declare_expertise_v1.agent_id,
        domains => Cmd#declare_expertise_v1.domains
    }.

-spec from_map(map()) -> {ok, declare_expertise_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_agent_id(#declare_expertise_v1{agent_id = V}) -> V.
get_domains(#declare_expertise_v1{domains = V}) -> V.
