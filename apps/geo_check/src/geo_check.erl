%%% @doc geo_check - Main API module for geographic restriction checks
%%%
%%% Provides functions to check if an IP address or the local machine
%%% is allowed to use the service based on geographic restrictions.
%%%
%%% Example:
%%% ```
%%% allowed = geo_check:check_local().
%%% {blocked, <<"RU">>} = geo_check:check_ip({93, 184, 216, 34}).
%%% '''
-module(geo_check).

-export([
    check_local/0,
    check_ip/1,
    get_country/1,
    get_location/1,
    get_asn/1,
    get_public_ip/0,
    reload_config/0,
    status/0
]).

-type ip_address() :: inet:ip_address() | binary() | string().
-type check_result() :: allowed | {blocked, CountryCode :: binary()}.

-export_type([check_result/0]).

%% @doc Check if the local machine is allowed based on its public IP
-spec check_local() -> check_result().
check_local() ->
    case get_public_ip() of
        {ok, IP} ->
            check_ip(IP);
        {error, _Reason} ->
            %% If we can't determine public IP, assume offline mode - allow
            allowed
    end.

%% @doc Check if an IP address is allowed
-spec check_ip(ip_address()) -> check_result().
check_ip(IP) when is_binary(IP) ->
    case inet:parse_address(binary_to_list(IP)) of
        {ok, IPTuple} -> check_ip(IPTuple);
        {error, _} -> allowed  %% Invalid IP format, allow (will fail elsewhere)
    end;
check_ip(IP) when is_list(IP) ->
    case inet:parse_address(IP) of
        {ok, IPTuple} -> check_ip(IPTuple);
        {error, _} -> allowed
    end;
check_ip(IP) when is_tuple(IP) ->
    %% First check IP overrides
    case geo_check_config:check_ip_override(IP) of
        allow -> allowed;
        deny -> {blocked, <<"IP_BLOCKED">>};
        continue -> check_ip_country(IP)
    end.

%% @private Check country-based restrictions
check_ip_country(IP) ->
    case get_country(IP) of
        {ok, CountryCode} ->
            check_country(CountryCode);
        {error, not_found} ->
            %% Unknown location - allow by default
            allowed;
        {error, _Reason} ->
            %% Database not ready - allow by default
            allowed
    end.

%% @doc Get the country code for an IP address
-spec get_country(ip_address()) -> {ok, binary()} | {error, term()}.
get_country(IP) when is_binary(IP) ->
    case inet:parse_address(binary_to_list(IP)) of
        {ok, IPTuple} -> get_country(IPTuple);
        {error, Reason} -> {error, Reason}
    end;
get_country(IP) when is_list(IP) ->
    case inet:parse_address(IP) of
        {ok, IPTuple} -> get_country(IPTuple);
        {error, Reason} -> {error, Reason}
    end;
get_country(IP) when is_tuple(IP) ->
    case locus:lookup(geo_city, IP) of
        {ok, #{<<"country">> := #{<<"iso_code">> := CountryCode}}} ->
            {ok, CountryCode};
        {ok, _Other} ->
            {error, no_country_data};
        not_found ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Get location details (city, country, lat/lng) for an IP address
-spec get_location(ip_address()) -> {ok, map()} | {error, term()}.
get_location(IP) when is_binary(IP) ->
    case inet:parse_address(binary_to_list(IP)) of
        {ok, IPTuple} -> get_location(IPTuple);
        {error, Reason} -> {error, Reason}
    end;
get_location(IP) when is_list(IP) ->
    case inet:parse_address(IP) of
        {ok, IPTuple} -> get_location(IPTuple);
        {error, Reason} -> {error, Reason}
    end;
get_location(IP) when is_tuple(IP) ->
    case locus:lookup(geo_city, IP) of
        {ok, Entry} ->
            Location = #{
                country => deep_get([<<"country">>, <<"iso_code">>], Entry),
                country_name => deep_get([<<"country">>, <<"names">>, <<"en">>], Entry),
                city => deep_get([<<"city">>, <<"names">>, <<"en">>], Entry),
                lat => deep_get([<<"location">>, <<"latitude">>], Entry),
                lng => deep_get([<<"location">>, <<"longitude">>], Entry),
                continent => deep_get([<<"continent">>, <<"code">>], Entry)
            },
            {ok, Location};
        not_found ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Get ASN (Autonomous System) info for an IP address
-spec get_asn(ip_address()) -> {ok, map()} | {error, term()}.
get_asn(IP) when is_binary(IP) ->
    case inet:parse_address(binary_to_list(IP)) of
        {ok, IPTuple} -> get_asn(IPTuple);
        {error, Reason} -> {error, Reason}
    end;
get_asn(IP) when is_list(IP) ->
    case inet:parse_address(IP) of
        {ok, IPTuple} -> get_asn(IPTuple);
        {error, Reason} -> {error, Reason}
    end;
get_asn(IP) when is_tuple(IP) ->
    case locus:lookup(geo_asn, IP) of
        {ok, #{<<"autonomous_system_number">> := ASN} = Entry} ->
            Info = #{
                asn => ASN,
                organization => maps:get(<<"autonomous_system_organization">>, Entry, undefined)
            },
            {ok, Info};
        {ok, _Other} ->
            {error, no_asn_data};
        not_found ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Get the machine's public IP address
-spec get_public_ip() -> {ok, inet:ip_address()} | {error, term()}.
get_public_ip() ->
    %% Try multiple services for redundancy
    Services = [
        "https://api.ipify.org",
        "https://icanhazip.com",
        "https://ifconfig.me/ip"
    ],
    try_ip_services(Services).

%% @doc Reload the geo restriction configuration
-spec reload_config() -> ok | {error, term()}.
reload_config() ->
    geo_check_config:reload().

%% @doc Get current status of the geo-check system
-spec status() -> map().
status() ->
    #{
        enabled => application:get_env(geo_check, enabled, true),
        city_loaded => is_loader_ready(geo_city),
        asn_loaded => is_loader_ready(geo_asn),
        config => geo_check_config:get_config(),
        local_check => check_local()
    }.

%%% Internal functions

%% @private Check country against configuration
check_country(CountryCode) ->
    Config = geo_check_config:get_config(),
    Mode = maps:get(mode, Config, blocklist),
    check_country_mode(Mode, CountryCode, Config).

check_country_mode(blocklist, CountryCode, Config) ->
    BlockedCountries = maps:get(blocked_countries, Config, []),
    case lists:member(CountryCode, BlockedCountries) of
        true -> {blocked, CountryCode};
        false -> allowed
    end;
check_country_mode(allowlist, CountryCode, Config) ->
    AllowedCountries = maps:get(allowed_countries, Config, []),
    case lists:member(CountryCode, AllowedCountries) of
        true -> allowed;
        false -> {blocked, CountryCode}
    end.

%% @private Try IP lookup services in order
try_ip_services([]) ->
    {error, all_services_failed};
try_ip_services([Url | Rest]) ->
    case hackney:get(Url, [], <<>>, [{timeout, 5000}, {recv_timeout, 5000}]) of
        {ok, 200, _Headers, ClientRef} ->
            case hackney:body(ClientRef) of
                {ok, Body} ->
                    IPStr = string:trim(binary_to_list(Body)),
                    case inet:parse_address(IPStr) of
                        {ok, IP} -> {ok, IP};
                        {error, _} -> try_ip_services(Rest)
                    end;
                {error, _} ->
                    try_ip_services(Rest)
            end;
        _ ->
            try_ip_services(Rest)
    end.

%% @private Check if a locus loader is ready
is_loader_ready(LoaderId) ->
    case locus:await_loader(LoaderId, 0) of
        {ok, _Version} -> true;
        {error, timeout} -> false;
        {error, _} -> false
    end.

%% @private Safely navigate nested maps
deep_get([], Value) -> Value;
deep_get([Key | Rest], Map) when is_map(Map) ->
    case maps:get(Key, Map, undefined) of
        undefined -> undefined;
        Value -> deep_get(Rest, Value)
    end;
deep_get(_, _) -> undefined.
