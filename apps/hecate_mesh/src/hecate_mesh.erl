-module(hecate_mesh).

-export([
    publish/2,
    subscribe/2,
    unsubscribe/1,
    advertise/2,
    call/3,
    call/4,
    get_client/0,
    get_status/0,
    is_connected/0,
    discover_subscribers/1,
    get_peers/0,
    get_proof_results/0,
    rerun_proof/0,
    get_neighborhood/0
]).

-spec publish(binary(), map()) -> ok | {error, term()}.
publish(Topic, Payload) ->
    hecate_mesh_client:publish(Topic, Payload).

-spec subscribe(binary(), fun()) -> {ok, reference()} | {error, term()}.
subscribe(Topic, Callback) ->
    hecate_mesh_client:subscribe(Topic, Callback).

-spec unsubscribe(reference()) -> ok | {error, term()}.
unsubscribe(SubRef) ->
    hecate_mesh_client:unsubscribe(SubRef).

-spec advertise(binary(), fun()) -> {ok, reference()} | {error, term()}.
advertise(Procedure, Handler) ->
    hecate_mesh_client:advertise(Procedure, Handler).

-spec call(binary(), map(), timeout()) -> {ok, term()} | {error, term()}.
call(Procedure, Args, Timeout) ->
    hecate_mesh_client:call(Procedure, Args, Timeout).

-spec call(binary(), map(), map(), timeout()) -> {ok, term()} | {error, term()}.
call(Procedure, Args, _Opts, Timeout) ->
    hecate_mesh_client:call(Procedure, Args, Timeout).

-spec get_client() -> {ok, pid()} | {error, term()}.
get_client() ->
    hecate_mesh_client:get_client().

-spec get_status() -> {ok, map()} | {error, term()}.
get_status() ->
    hecate_mesh_client:get_status().

-spec is_connected() -> boolean().
is_connected() ->
    case hecate_mesh_client:get_client() of
        {ok, Pid} when is_pid(Pid) -> true;
        _ -> false
    end.

-spec discover_subscribers(binary()) -> {ok, list()} | {error, term()}.
discover_subscribers(Topic) ->
    hecate_mesh_client:discover_subscribers(Topic).

-spec get_peers() -> {ok, list()}.
get_peers() ->
    %% In relay mode, peers are managed by the relay, not tracked locally.
    %% The relay /status endpoint exposes connected nodes.
    {ok, []}.

-spec get_proof_results() -> map().
get_proof_results() ->
    mesh_proof_coordinator:get_proof_results().

-spec rerun_proof() -> ok.
rerun_proof() ->
    mesh_proof_coordinator:rerun_probes().

-spec get_neighborhood() -> {ok, map()}.
get_neighborhood() ->
    %% Get ranked relay list from SDK discovery cache
    Ranked = try macula_relay_discovery:ranked_relays()
             catch _:_ -> [] end,
    TotalKnown = try macula_relay_discovery:relay_count()
                 catch _:_ -> 0 end,
    %% Get current relay from multi_relay status
    CurrentRelay = current_relay_info(),
    OnlineCount = length([R || R <- Ranked, maps:get(status, R) =:= online]),
    {ok, #{
        current_relay => CurrentRelay,
        nearby_relays => Ranked,
        total_known => TotalKnown,
        total_online => OnlineCount
    }}.

%%====================================================================
%% Internal — relay info extraction
%%====================================================================

current_relay_info() ->
    case get_status() of
        {ok, #{multi_relay := #{connections := Conns}}} ->
            primary_relay_info(Conns);
        _ -> null
    end.

primary_relay_info([]) -> null;
primary_relay_info([#{relay := Url, role := <<"primary">>, alive := true} | _]) ->
    Hostname = extract_hostname(Url),
    enrich_relay(Hostname);
primary_relay_info([_ | Rest]) ->
    primary_relay_info(Rest).

extract_hostname(Url) ->
    %% <<"https://relay-de-berlin.macula.io:4433">> → <<"relay-de-berlin.macula.io">>
    Stripped = re:replace(Url, <<"^https?://">>, <<>>, [{return, binary}]),
    re:replace(Stripped, <<":\\d+.*">>, <<>>, [{return, binary}]).

enrich_relay(Hostname) ->
    {City, Country} = parse_city_country(Hostname),
    Base = #{hostname => Hostname, city => City, country => Country},
    case catch macula_relay_discovery:lookup(Hostname) of
        {ok, Info} ->
            maps:merge(Base, maps:with([lat, lng, distance_km, rtt_ms, status], Info));
        _ ->
            Base
    end.

parse_city_country(Hostname) ->
    %% <<"relay-de-berlin.macula.io">> → {<<"Berlin">>, <<"DE">>}
    case re:run(Hostname, <<"^relay-([a-z]{2})-([a-z-]+)\\.">>,
                [{capture, [1, 2], binary}]) of
        {match, [Country, RawCity]} ->
            City = titlecase(binary:replace(RawCity, <<"-">>, <<" ">>, [global])),
            {City, string:uppercase(Country)};
        nomatch ->
            {null, null}
    end.

titlecase(<<>>) -> <<>>;
titlecase(<<First, Rest/binary>>) ->
    Upper = string:uppercase(<<First>>),
    titlecase_rest(Rest, Upper).

titlecase_rest(<<>>, Acc) -> Acc;
titlecase_rest(<<" ", C, Rest/binary>>, Acc) ->
    Upper = string:uppercase(<<C>>),
    titlecase_rest(Rest, <<Acc/binary, " ", Upper/binary>>);
titlecase_rest(<<C, Rest/binary>>, Acc) ->
    titlecase_rest(Rest, <<Acc/binary, C>>).

