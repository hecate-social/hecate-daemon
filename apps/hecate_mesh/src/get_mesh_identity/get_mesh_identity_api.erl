%%% @doc GET /api/mesh/identity — Who am I on the mesh.
%%%
%%% Returned shape (consumed by macula-mcp / any local agent harness):
%%%
%%%   #{
%%%     node_id    => <agent_id, 32-byte ed25519 pubkey, hex>,
%%%     mri        => <macula resource identifier, binary>,
%%%     realm      => <realm id> | null,
%%%     membership => idle | joining | joined | failed,
%%%     mesh       => #{ activated => bool, connected => bool }
%%%   }
%%%
%%% An agent SHOULD read this before it acts: every Macula leaf chains
%%% to an accountable realm + foundation, and the agent's actions carry
%%% whichever authority this node already holds.
%%% @end
-module(get_mesh_identity_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/identity", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    NodeId   = encode_agent_id(safe(fun hecate_identity:agent_id/0)),
    MRI      = nullable(safe(fun hecate_identity:get_mri/0)),
    Realm    = nullable(safe(fun hecate_identity:get_realm/0)),
    Membership = membership_status(),
    MeshInfo = mesh_info(),
    hecate_api_utils:json_ok(#{
        node_id    => NodeId,
        mri        => MRI,
        realm      => Realm,
        membership => Membership,
        mesh       => MeshInfo
    }, Req0).

%% @private Stringify a 32-byte agent pubkey as lowercase hex; tolerate
%% other shapes (binary already, undefined, list) without crashing the
%% endpoint — identity is observability, not load-bearing here.
encode_agent_id(undefined) -> null;
encode_agent_id(<<Bytes/binary>>) when byte_size(Bytes) =:= 32 ->
    list_to_binary(lists:flatten(
        [io_lib:format("~2.16.0b", [B]) || <<B>> <= Bytes]));
encode_agent_id(Other) when is_binary(Other) -> Other;
encode_agent_id(Other) -> iolist_to_binary(io_lib:format("~p", [Other])).

%% @private hecate_realm_session:get_status/0 returns a state map with a
%% `status` field (idle | joining | joined | failed).
membership_status() ->
    try hecate_realm_session:get_status() of
        #{status := S} when is_atom(S) -> S;
        _ -> idle
    catch
        _:_ -> idle
    end.

mesh_info() ->
    Activated = safe_bool(fun hecate_mesh:is_activated/0),
    Connected = safe_bool(fun hecate_mesh:is_connected/0),
    #{activated => Activated, connected => Connected}.

%% @private hecate_identity gen_server calls return `{ok, X}' or bare
%% values depending on the state. Swallow exits during boot.
safe(Fun) ->
    try Fun() of
        {ok, V} -> V;
        V -> V
    catch
        _:_ -> undefined
    end.

safe_bool(Fun) ->
    case safe(Fun) of
        true -> true;
        _ -> false
    end.

nullable(undefined) -> null;
nullable(V) -> V.
