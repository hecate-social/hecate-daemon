%%% @doc Aggregate for site lifecycle.
%%%
%%% Singleton aggregate per site installation.
%%% Stream: site-{site_id} where site_id = first 16 hex chars of sha256(cookie).
%%% Lifecycle: initiate, admit_node / remove_node.
%%%
%%% Realm memberships are SEPARATE aggregates in the same store (site_store).
%%% See membership_aggregate in guide_realm_memberships.
-module(site_aggregate).
-behaviour(evoq_aggregate).

-include("site_state.hrl").
-include("site_status.hrl").

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% State module + stream routing
-export([state_module/0, stream_id/1]).

-spec state_module() -> module().
state_module() -> site_state.

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

init(AggregateId) ->
    {ok, site_state:new(AggregateId)}.

-spec stream_id(binary()) -> binary().
stream_id(SiteId) ->
    <<"site-", SiteId/binary>>.

%% @doc Execute command — State FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Apply event — State FIRST. Delegates to state module.
apply(State, Event) ->
    site_state:apply_event(State, Event).

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(initiate_site, State, Payload) ->
    case State#site_state.status band ?SITE_INITIATED of
        0 -> maybe_initiate_site:handle_from_map(Payload);
        _ -> {error, already_initiated}
    end;

do_execute(admit_node, State, Payload) ->
    case State#site_state.status band ?SITE_INITIATED of
        0 -> {error, not_initiated};
        _ ->
            NodeName = maps:get(node_name, Payload, maps:get(<<"node_name">>, Payload, <<>>)),
            case maps:is_key(NodeName, State#site_state.nodes) of
                true -> {error, node_already_admitted};
                false -> maybe_admit_node:handle_from_map(Payload)
            end
    end;

do_execute(remove_node, State, Payload) ->
    NodeName = maps:get(node_name, Payload, maps:get(<<"node_name">>, Payload, <<>>)),
    case maps:is_key(NodeName, State#site_state.nodes) of
        false -> {error, node_not_admitted};
        true -> maybe_remove_node:handle_from_map(Payload)
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.
