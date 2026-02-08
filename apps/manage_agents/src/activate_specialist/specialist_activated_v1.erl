%%% @doc specialist_activated_v1 event
%%% Emitted when a specialist agent is successfully activated.
-module(specialist_activated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_agent_id/1, get_torch_id/1, get_role/1, get_activated_at/1]).

-record(specialist_activated_v1, {
    agent_id     :: binary(),
    torch_id     :: binary(),
    role         :: dna | anp | tni | dno,
    activated_at :: integer()
}).

-export_type([specialist_activated_v1/0]).
-opaque specialist_activated_v1() :: #specialist_activated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> specialist_activated_v1().
new(#{agent_id := AgentId, torch_id := TorchId, role := Role} = _Params) ->
    #specialist_activated_v1{
        agent_id = AgentId,
        torch_id = TorchId,
        role = Role,
        activated_at = erlang:system_time(millisecond)
    }.

-spec to_map(specialist_activated_v1()) -> map().
to_map(#specialist_activated_v1{} = E) ->
    #{
        <<"event_type">> => <<"specialist_activated_v1">>,
        <<"agent_id">> => E#specialist_activated_v1.agent_id,
        <<"torch_id">> => E#specialist_activated_v1.torch_id,
        <<"role">> => atom_to_binary(E#specialist_activated_v1.role, utf8),
        <<"activated_at">> => E#specialist_activated_v1.activated_at
    }.

-spec from_map(map()) -> {ok, specialist_activated_v1()} | {error, term()}.
from_map(Map) ->
    AgentId = get_value(agent_id, Map),
    TorchId = get_value(torch_id, Map),
    RoleRaw = get_value(role, Map),
    case {AgentId, TorchId, RoleRaw} of
        {undefined, _, _} -> {error, invalid_event};
        {_, undefined, _} -> {error, invalid_event};
        {_, _, undefined} -> {error, invalid_event};
        _ ->
            Role = binary_to_role(RoleRaw),
            {ok, #specialist_activated_v1{
                agent_id = AgentId,
                torch_id = TorchId,
                role = Role,
                activated_at = get_value(activated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_agent_id(specialist_activated_v1()) -> binary().
get_agent_id(#specialist_activated_v1{agent_id = V}) -> V.

-spec get_torch_id(specialist_activated_v1()) -> binary().
get_torch_id(#specialist_activated_v1{torch_id = V}) -> V.

-spec get_role(specialist_activated_v1()) -> dna | anp | tni | dno.
get_role(#specialist_activated_v1{role = V}) -> V.

-spec get_activated_at(specialist_activated_v1()) -> integer().
get_activated_at(#specialist_activated_v1{activated_at = V}) -> V.

%% Helper to convert binary role to atom
binary_to_role(<<"dna">>) -> dna;
binary_to_role(<<"anp">>) -> anp;
binary_to_role(<<"tni">>) -> tni;
binary_to_role(<<"dno">>) -> dno;
binary_to_role(Role) when is_atom(Role) -> Role.

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
