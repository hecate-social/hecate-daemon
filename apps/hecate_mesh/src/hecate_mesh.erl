-module(hecate_mesh).

-export([
    publish/2,
    subscribe/2,
    unsubscribe/1,
    advertise/2,
    call/3,
    call/4,
    %% DHT record API (PLAN_DHT_FIRST.md)
    put_record/1,
    find_record/1,
    find_records_by_type/1,
    get_client/0,
    get_status/0,
    is_connected/0,
    discover_subscribers/1,
    get_peers/0,
    get_proof_results/0,
    rerun_proof/0,
    get_neighborhood/0,
    %% Local-first: deferred mesh registration
    activate/0,
    is_activated/0,
    register_subscription/2,
    register_advertisement/2
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

%% @doc Put a signed `macula_record:record()' into the mesh DHT.
-spec put_record(macula_record:record()) -> ok | {error, term()}.
put_record(Record) ->
    hecate_mesh_client:put_record(Record).

%% @doc Fetch a record by its `macula_record:storage_key/1'.
-spec find_record(<<_:256>>) -> {ok, macula_record:record()} | {error, term()}.
find_record(Key) ->
    hecate_mesh_client:find_record(Key).

%% @doc List every locally-known record of a given type tag.
-spec find_records_by_type(macula_record:type_tag()) ->
        {ok, [macula_record:record()]} | {error, term()}.
find_records_by_type(Type) ->
    hecate_mesh_client:find_records_by_type(Type).

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
    {ok, []}.

-spec get_proof_results() -> map().
get_proof_results() ->
    mesh_proof_coordinator:get_proof_results().

-spec rerun_proof() -> ok.
rerun_proof() ->
    mesh_proof_coordinator:rerun_probes().

%% @doc Activate mesh — connect to relays. Called after UI is up.
-spec activate() -> ok | {error, already_activated}.
activate() ->
    hecate_mesh_client:activate().

%% @doc Check if mesh has been activated.
-spec is_activated() -> boolean().
is_activated() ->
    hecate_mesh_client:is_activated().

%% @doc Register a subscription to be applied when mesh activates.
-spec register_subscription(binary(), fun()) -> ok.
register_subscription(Topic, Callback) ->
    hecate_mesh_client:register_subscription(Topic, Callback).

%% @doc Register an advertisement to be applied when mesh activates.
-spec register_advertisement(binary(), fun()) -> ok.
register_advertisement(Procedure, Handler) ->
    hecate_mesh_client:register_advertisement(Procedure, Handler).

-spec get_neighborhood() -> {ok, map()}.
get_neighborhood() ->
    Ranked = try macula_relay_discovery:ranked_relays()
             catch _:_ -> [] end,
    TotalKnown = try macula_relay_discovery:relay_count()
                 catch _:_ -> 0 end,
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
