%%% @doc Projection: lan_machine_spotted_v1 + lan_machine_dismissed_v1
%%% -> lan_machines ETS.
%%%
%%% Each MAC keeps per-observer observations and per-observer dismissals.
%%% Fallback observer `<<"unknown">>` covers legacy events written before
%%% streams were keyed by observer.
%%% @end
-module(lan_machine_spotted_v1_to_lan_machines).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, lan_machines).

interested_in() ->
    [<<"lan_machine_spotted_v1">>,
     <<"lan_machine_dismissed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"lan_machine_spotted_v1">>   -> project_spotted(Data, State, RM);
        <<"lan_machine_dismissed_v1">> -> project_dismissed(Data, State, RM);
        _                              -> {ok, State, RM}
    end.

%% --- Spotted: merge per-observer observation ---

project_spotted(Data, State, RM) ->
    MAC = gf(mac, Data),
    case MAC of
        undefined -> {ok, State, RM};
        _ ->
            Observer = gf(observer, Data),
            SafeObserver = case Observer of
                undefined -> <<"unknown">>;
                _ -> Observer
            end,
            Observation = #{
                ip         => gf(ip, Data),
                hostname   => gf(hostname, Data),
                interface  => gf(interface, Data),
                ssh        => gf(ssh, Data),
                hecate     => gf(hecate, Data),
                spotted_at => gf(spotted_at, Data)
            },
            Existing = existing_row(MAC),
            Observations = maps:get(observations, Existing, #{}),
            NewObservations = maps:put(SafeObserver, Observation, Observations),
            Row = Existing#{
                mac          => MAC,
                observations => NewObservations
            },
            {ok, RM2} = evoq_read_model:put(MAC, Row, RM),
            {ok, State, RM2}
    end.

%% --- Dismissed: mark per-observer dismissal ---

project_dismissed(Data, State, RM) ->
    MAC = gf(mac, Data),
    case MAC of
        undefined -> {ok, State, RM};
        _ ->
            Observer = gf(observer, Data),
            SafeObserver = case Observer of
                undefined -> <<"unknown">>;
                _ -> Observer
            end,
            DismissedAt = gf(dismissed_at, Data),
            Existing = existing_row(MAC),
            DismissedBy = maps:get(dismissed_by, Existing, #{}),
            NewDismissedBy = maps:put(SafeObserver, DismissedAt, DismissedBy),
            Row = Existing#{
                mac          => MAC,
                dismissed_by => NewDismissedBy
            },
            {ok, RM2} = evoq_read_model:put(MAC, Row, RM),
            {ok, State, RM2}
    end.

%% --- Internal ---

existing_row(MAC) ->
    case ets:lookup(?TABLE, MAC) of
        [{_, Row}] -> Row;
        [] -> #{mac => MAC, observations => #{}, dismissed_by => #{}}
    end.

get_event_type(#{event_type := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
