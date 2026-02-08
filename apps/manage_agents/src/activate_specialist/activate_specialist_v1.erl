%%% @doc activate_specialist_v1 command
%%% Activates a specialist agent for a specific role in the ALC lifecycle.
-module(activate_specialist_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_agent_id/1, get_torch_id/1, get_role/1]).
-export([generate_id/0]).

-record(activate_specialist_v1, {
    agent_id :: binary(),
    torch_id :: binary(),
    role     :: dna | anp | tni | dno
}).

-export_type([activate_specialist_v1/0]).
-opaque activate_specialist_v1() :: #activate_specialist_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, activate_specialist_v1()} | {error, term()}.
new(#{torch_id := TorchId, role := Role} = Params) ->
    AgentId = maps:get(agent_id, Params, generate_id()),
    case validate_role(Role) of
        {ok, ValidRole} ->
            {ok, #activate_specialist_v1{
                agent_id = AgentId,
                torch_id = TorchId,
                role = ValidRole
            }};
        {error, Reason} ->
            {error, Reason}
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(activate_specialist_v1()) -> {ok, activate_specialist_v1()} | {error, term()}.
validate(#activate_specialist_v1{torch_id = TorchId}) when
    not is_binary(TorchId); byte_size(TorchId) =:= 0 ->
    {error, invalid_torch_id};
validate(#activate_specialist_v1{role = Role}) when
    Role =/= dna, Role =/= anp, Role =/= tni, Role =/= dno ->
    {error, invalid_role};
validate(#activate_specialist_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(activate_specialist_v1()) -> map().
to_map(#activate_specialist_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"activate_specialist">>,
        <<"agent_id">> => Cmd#activate_specialist_v1.agent_id,
        <<"torch_id">> => Cmd#activate_specialist_v1.torch_id,
        <<"role">> => atom_to_binary(Cmd#activate_specialist_v1.role, utf8)
    }.

-spec from_map(map()) -> {ok, activate_specialist_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    RoleRaw = get_value(role, Map),
    AgentId = get_value(agent_id, Map, generate_id()),
    case {TorchId, RoleRaw} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            case validate_role(RoleRaw) of
                {ok, Role} ->
                    {ok, #activate_specialist_v1{
                        agent_id = AgentId,
                        torch_id = TorchId,
                        role = Role
                    }};
                {error, Reason} ->
                    {error, Reason}
            end
    end.

%% Accessors
-spec get_agent_id(activate_specialist_v1()) -> binary().
get_agent_id(#activate_specialist_v1{agent_id = V}) -> V.

-spec get_torch_id(activate_specialist_v1()) -> binary().
get_torch_id(#activate_specialist_v1{torch_id = V}) -> V.

-spec get_role(activate_specialist_v1()) -> dna | anp | tni | dno.
get_role(#activate_specialist_v1{role = V}) -> V.

%% @doc Generate a unique agent ID
-spec generate_id() -> binary().
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"agent-", Ts/binary, "-", Rand/binary>>.

%% Internal: validate and normalize role
validate_role(dna) -> {ok, dna};
validate_role(anp) -> {ok, anp};
validate_role(tni) -> {ok, tni};
validate_role(dno) -> {ok, dno};
validate_role(<<"dna">>) -> {ok, dna};
validate_role(<<"anp">>) -> {ok, anp};
validate_role(<<"tni">>) -> {ok, tni};
validate_role(<<"dno">>) -> {ok, dno};
validate_role(_) -> {error, invalid_role}.

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
