%%%-------------------------------------------------------------------
%%% @doc Process manager: realm membership confirmed -> activate mesh.
%%%
%%% When a realm membership is confirmed (OAuth complete), the daemon
%%% auto-activates the mesh connection. This replaces the frontend
%%% logic that called POST /api/mesh/activate after realm join.
%%%
%%% Lives in hecate_mesh (the target domain) because it produces
%%% the activate action. Subscribes to realm_memberships_store events.
%%% @end
%%%-------------------------------------------------------------------
-module(on_realm_membership_confirmed_activate_mesh).

-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"realm_membership_confirmed_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, _Event, _Metadata, State) ->
    case hecate_mesh:is_activated() of
        true ->
            logger:info("[on_realm_membership_confirmed_activate_mesh] mesh already activated");
        false ->
            logger:info("[on_realm_membership_confirmed_activate_mesh] realm joined — activating mesh"),
            case hecate_mesh:activate() of
                ok ->
                    logger:info("[on_realm_membership_confirmed_activate_mesh] mesh activated");
                {error, Reason} ->
                    logger:warning("[on_realm_membership_confirmed_activate_mesh] activate failed: ~p", [Reason])
            end
    end,
    {ok, State}.
