%%% @doc Aggregate for settings lifecycle.
%%%
%%% One singleton per daemon. Stream: settings-{linux_user}@{hostname}.
%%% Manages: identity, pairing, api keys, preferences.
-module(settings_aggregate).

-include("settings_status.hrl").

-export([initial_state/0, execute/2, apply_event/2, stream_id/0]).

-record(settings_state, {
    linux_user     :: binary() | undefined,
    hostname       :: binary() | undefined,
    github_user    :: binary() | undefined,
    realm          :: binary() | undefined,
    paired         :: boolean(),
    paired_at      :: integer() | undefined,
    api_keys       :: #{binary() => map()},
    preferences    :: map(),
    status         :: non_neg_integer(),
    initiated_at   :: integer() | undefined
}).

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

initial_state() ->
    #settings_state{
        linux_user = undefined,
        hostname = undefined,
        github_user = undefined,
        realm = undefined,
        paired = false,
        paired_at = undefined,
        api_keys = #{},
        preferences = #{},
        status = 0,
        initiated_at = undefined
    }.

%% @doc Deterministic stream ID for this daemon's settings.
-spec stream_id() -> binary().
stream_id() ->
    User = list_to_binary(string:trim(os:cmd("whoami"), trailing, "\n")),
    Host = list_to_binary(string:trim(os:cmd("hostname -s"), trailing, "\n")),
    <<"settings-", User/binary, "@", Host/binary>>.

%% @doc Execute command - routes to the correct handler.
%% State comes FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Apply event to state.
apply_event(State, #{<<"event_type">> := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(initiate_settings, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> maybe_initiate_settings:handle_from_map(Payload);
        _ -> {error, already_initiated}
    end;

do_execute(pair_node, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> {error, not_initiated};
        _ ->
            case State#settings_state.status band ?SETTINGS_PAIRED of
                0 -> maybe_pair_node:handle_from_map(Payload);
                _ -> {error, already_paired}
            end
    end;

do_execute(unpair_node, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_PAIRED of
        0 -> {error, not_paired};
        _ -> maybe_unpair_node:handle_from_map(Payload)
    end;

do_execute(configure_api_key, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> {error, not_initiated};
        _ -> maybe_configure_api_key:handle_from_map(Payload)
    end;

do_execute(remove_api_key, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> {error, not_initiated};
        _ ->
            Provider = maps:get(provider, Payload, maps:get(<<"provider">>, Payload, undefined)),
            case maps:is_key(Provider, State#settings_state.api_keys) of
                true -> maybe_remove_api_key:handle_from_map(Payload);
                false -> {error, provider_not_found}
            end
    end;

do_execute(update_preferences, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> {error, not_initiated};
        _ -> maybe_update_preferences:handle_from_map(Payload)
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

%% ===================================================================
%% Event application
%% ===================================================================

do_apply(<<"settings_initiated_v1">>, State, Event) ->
    State#settings_state{
        linux_user = get_field(<<"linux_user">>, linux_user, Event),
        hostname = get_field(<<"hostname">>, hostname, Event),
        initiated_at = get_field(<<"initiated_at">>, initiated_at, Event),
        status = State#settings_state.status bor ?SETTINGS_INITIATED
    };

do_apply(<<"node_paired_v1">>, State, Event) ->
    State#settings_state{
        github_user = get_field(<<"github_user">>, github_user, Event),
        realm = get_field(<<"realm">>, realm, Event),
        paired = true,
        paired_at = get_field(<<"paired_at">>, paired_at, Event),
        status = State#settings_state.status bor ?SETTINGS_PAIRED
    };

do_apply(<<"node_unpaired_v1">>, State, _Event) ->
    State#settings_state{
        github_user = undefined,
        realm = undefined,
        paired = false,
        paired_at = undefined,
        status = State#settings_state.status band (bnot ?SETTINGS_PAIRED)
    };

do_apply(<<"api_key_configured_v1">>, State, Event) ->
    Provider = get_field(<<"provider">>, provider, Event),
    KeyData = #{
        api_key => get_field(<<"api_key">>, api_key, Event),
        label => get_field(<<"label">>, label, Event),
        configured_at => get_field(<<"configured_at">>, configured_at, Event)
    },
    State#settings_state{
        api_keys = maps:put(Provider, KeyData, State#settings_state.api_keys)
    };

do_apply(<<"api_key_removed_v1">>, State, Event) ->
    Provider = get_field(<<"provider">>, provider, Event),
    State#settings_state{
        api_keys = maps:remove(Provider, State#settings_state.api_keys)
    };

do_apply(<<"preferences_updated_v1">>, State, Event) ->
    NewPrefs = get_field(<<"preferences">>, preferences, Event),
    Merged = case is_map(NewPrefs) of
        true -> maps:merge(State#settings_state.preferences, NewPrefs);
        false -> State#settings_state.preferences
    end,
    State#settings_state{preferences = Merged};

do_apply(_UnknownType, State, _Event) ->
    State.

%% ===================================================================
%% Internal
%% ===================================================================

%% @doc Get field from event map, supporting both atom and binary keys.
get_field(BinKey, AtomKey, Event) ->
    maps:get(BinKey, Event, maps:get(AtomKey, Event, undefined)).
