%%%-------------------------------------------------------------------
%%% @doc Viewstate — daemon computes all presentation state.
%%%
%%% The frontend is a pure renderer. This module computes icons,
%%% labels, variants, and sublabels for every UI region. The web/TUI
%%% maps semantic variants to CSS classes and renders.
%%%
%%% Called by the health endpoint on every poll.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_viewstate).

-export([compute/0]).

-spec compute() -> map().
compute() ->
    #{
        header => header_viewstate(),
        startup => startup_viewstate()
    }.

%%====================================================================
%% Header viewstate
%%====================================================================

header_viewstate() ->
    #{
        daemon => daemon_indicator(),
        mesh => mesh_indicator(),
        realm => realm_indicator()
    }.

%% --- Daemon LED ---

daemon_indicator() ->
    case hecate_lifecycle:get_state() of
        running ->
            #{icon => <<"circle-filled">>, variant => <<"ok">>};
        stopping ->
            #{icon => <<"circle-filled">>, variant => <<"err">>};
        starting ->
            #{icon => <<"circle-outline">>, variant => <<"warn">>}
    end.

%% --- Mesh indicator ---
%%
%% States:
%%   not activated          → diamond-filled, neutral, "Local"
%%   activated, connecting  → diamond-outline, warn, "Connecting..."
%%   connected, no city     → circle-filled, ok, "Connected"
%%   connected, with city   → circle-filled, ok, "Berlin · 12ms", "287 relays"
%%   disconnected (was on)  → diamond-filled, neutral, "Local", "was Berlin"

mesh_indicator() ->
    Activated = try hecate_mesh:is_activated() catch _:_ -> false end,
    mesh_indicator(Activated).

mesh_indicator(false) ->
    #{icon => <<"diamond-filled">>, variant => <<"neutral">>,
      label => <<"Local">>, sublabel => null};
mesh_indicator(true) ->
    Neighborhood = try hecate_mesh:get_neighborhood() catch _:_ -> {ok, #{}} end,
    mesh_indicator_from_neighborhood(Neighborhood).

mesh_indicator_from_neighborhood({ok, #{current_relay := Relay, total_online := Online}})
  when is_map(Relay), Relay =/= null ->
    City = maps:get(city, Relay, null),
    Rtt = maps:get(rtt_ms, Relay, null),
    Label = format_relay_label(City, Rtt),
    Sublabel = case Online of
        N when is_integer(N), N > 0 ->
            iolist_to_binary([integer_to_binary(N), <<" relays">>]);
        _ -> null
    end,
    #{icon => <<"circle-filled">>, variant => <<"ok">>,
      label => Label, sublabel => Sublabel};
mesh_indicator_from_neighborhood({ok, #{total_online := Online}})
  when is_integer(Online), Online > 0 ->
    #{icon => <<"diamond-outline">>, variant => <<"warn">>,
      label => <<"Connecting...">>, sublabel => null};
mesh_indicator_from_neighborhood(_) ->
    #{icon => <<"diamond-filled">>, variant => <<"neutral">>,
      label => <<"Local">>, sublabel => null}.

format_relay_label(null, _Rtt) ->
    <<"Connected">>;
format_relay_label(City, null) ->
    City;
format_relay_label(City, Rtt) when is_number(Rtt) ->
    RttBin = integer_to_binary(round(Rtt)),
    iolist_to_binary([City, <<" \xC2\xB7 ">>, RttBin, <<"ms">>]).

%% --- Realm badge ---

realm_indicator() ->
    case try project_realm_memberships_store:list_confirmed() catch _:_ -> {ok, []} end of
        {ok, [#{realm_id := RealmId} | _]} ->
            #{visible => true, icon => <<"globe">>,
              variant => <<"accent">>, label => RealmId};
        _ ->
            #{visible => false, icon => <<"globe">>,
              variant => <<"dim">>, label => null}
    end.

%%====================================================================
%% Startup viewstate
%%====================================================================

startup_viewstate() ->
    DaemonState = hecate_lifecycle:get_state(),
    case DaemonState of
        running ->
            #{done => true, steps => running_steps()};
        _ ->
            Boot = try boot_daemon:get_status() catch _:_ -> #{} end,
            #{done => false, steps => boot_steps(Boot)}
    end.

running_steps() ->
    [
        step(<<"daemon">>,  <<"check">>,          <<"ok">>,      <<"Daemon">>,      <<"Connected">>),
        step(<<"stores">>,  <<"check">>,          <<"ok">>,      <<"Data stores">>, <<"Ready">>),
        step(<<"settings">>,<<"check">>,          <<"ok">>,      <<"Settings">>,    <<"Loaded">>),
        step(<<"plugins">>, <<"check">>,          <<"ok">>,      <<"Plugins">>,     <<"Ready">>)
    ].

boot_steps(#{stores_ready := Ready, stores_total := Total}) when Total > 0 ->
    StoreDetail = iolist_to_binary([integer_to_binary(Ready), <<"/">>, integer_to_binary(Total)]),
    StoreVariant = case Ready =:= Total of true -> <<"ok">>; false -> <<"warn">> end,
    StoreIcon = case Ready =:= Total of true -> <<"check">>; false -> <<"circle-filled">> end,
    [
        step(<<"daemon">>,  <<"check">>,    <<"ok">>,       <<"Daemon">>,      <<"Connected">>),
        step(<<"stores">>,  StoreIcon,      StoreVariant,   <<"Data stores">>, StoreDetail),
        step(<<"settings">>,<<"circle-outline">>, <<"neutral">>, <<"Settings">>, <<>>),
        step(<<"plugins">>, <<"circle-outline">>, <<"neutral">>, <<"Plugins">>,  <<>>)
    ];
boot_steps(_) ->
    [
        step(<<"daemon">>,  <<"circle-filled">>,  <<"warn">>,    <<"Daemon">>,      <<"Starting...">>),
        step(<<"stores">>,  <<"circle-outline">>,  <<"neutral">>, <<"Data stores">>, <<>>),
        step(<<"settings">>,<<"circle-outline">>,  <<"neutral">>, <<"Settings">>,    <<>>),
        step(<<"plugins">>, <<"circle-outline">>,  <<"neutral">>, <<"Plugins">>,     <<>>)
    ].

step(Id, Icon, Variant, Label, Detail) ->
    #{id => Id, icon => Icon, variant => Variant, label => Label, detail => Detail}.
