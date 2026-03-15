%%% @doc Aggregate for settings lifecycle.
%%%
%%% One singleton per daemon. Stream: settings-{linux_user}@{hostname}.
%%% Manages: identity, preferences.
%%% Realm memberships are handled by guide_realm_memberships.
-module(settings_aggregate).
-behaviour(evoq_aggregate).

-include("settings_state.hrl").
-include("settings_status.hrl").

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

-export([state_module/0, stream_id/0]).

-spec state_module() -> module().
state_module() -> settings_state.

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

init(AggregateId) ->
    {ok, settings_state:new(AggregateId)}.

-spec stream_id() -> binary().
stream_id() ->
    User = shared_host:user(),
    Host = shared_host:hostname(),
    <<"settings-", User/binary, "@", Host/binary>>.

%% @doc Execute command — State FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Evoq callback: apply/2 — State FIRST. Delegates to state module.
apply(State, Event) ->
    settings_state:apply_event(State, Event).

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(initiate_settings, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> maybe_initiate_settings:handle_from_map(Payload);
        _ -> {error, already_initiated}
    end;

do_execute(update_preferences, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> {error, not_initiated};
        _ -> maybe_update_preferences:handle_from_map(Payload)
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.
