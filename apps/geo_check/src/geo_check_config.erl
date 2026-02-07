%%% @doc geo_check_config - Configuration management for geo restrictions
%%%
%%% Loads and caches the geo restriction configuration from YAML file.
%%% Supports hot-reload of configuration.
-module(geo_check_config).
-behaviour(gen_server).

-include_lib("kernel/include/file.hrl").

-export([
    start_link/0,
    get_config/0,
    check_ip_override/1,
    reload/0
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).

-record(state, {
    config :: map(),
    config_file :: string(),
    last_modified :: calendar:datetime() | undefined
}).

%% @doc Start the config server
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Get the current configuration
-spec get_config() -> map().
get_config() ->
    gen_server:call(?SERVER, get_config).

%% @doc Check if an IP is in the override list
-spec check_ip_override(inet:ip_address()) -> allow | deny | continue.
check_ip_override(IP) ->
    gen_server:call(?SERVER, {check_ip_override, IP}).

%% @doc Reload configuration from file
-spec reload() -> ok | {error, term()}.
reload() ->
    gen_server:call(?SERVER, reload).

%%% gen_server callbacks

init([]) ->
    ConfigFile = application:get_env(geo_check, config_file, "config/geo_restrictions.yaml"),
    Config = load_config(ConfigFile),
    logger:info("[geo_check_config] Loaded config: mode=~p, blocked=~p, allowed=~p",
        [maps:get(mode, Config, undefined),
         length(maps:get(blocked_countries, Config, [])),
         length(maps:get(allowed_countries, Config, []))]),
    {ok, #state{
        config = Config,
        config_file = ConfigFile,
        last_modified = get_file_mtime(ConfigFile)
    }}.

handle_call(get_config, _From, #state{config = Config} = State) ->
    {reply, Config, State};

handle_call({check_ip_override, IP}, _From, #state{config = Config} = State) ->
    Result = check_override(IP, Config),
    {reply, Result, State};

handle_call(reload, _From, #state{config_file = ConfigFile} = State) ->
    case load_config(ConfigFile) of
        #{} = NewConfig ->
            logger:info("[geo_check_config] Reloaded configuration"),
            {reply, ok, State#state{
                config = NewConfig,
                last_modified = get_file_mtime(ConfigFile)
            }};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%% Internal functions

%% @private Load configuration from YAML file
load_config(ConfigFile) ->
    case file:read_file(ConfigFile) of
        {ok, Content} ->
            parse_yaml(Content);
        {error, enoent} ->
            logger:warning("[geo_check_config] Config file not found: ~s, using defaults", [ConfigFile]),
            default_config();
        {error, Reason} ->
            logger:warning("[geo_check_config] Failed to read config: ~p, using defaults", [Reason]),
            default_config()
    end.

%% @private Parse YAML content (simplified parser for our specific format)
%% Note: For full YAML support, consider adding yamerl dependency
parse_yaml(Content) ->
    Lines = binary:split(Content, <<"\n">>, [global]),
    parse_yaml_lines(Lines, #{}).

parse_yaml_lines([], Acc) ->
    Acc;
parse_yaml_lines([Line | Rest], Acc) ->
    case parse_yaml_line(Line) of
        {key, <<"mode">>, Value} ->
            parse_yaml_lines(Rest, Acc#{mode => Value});
        {key, <<"blocked_countries">>, _} ->
            {Countries, Remaining} = parse_yaml_list(Rest),
            parse_yaml_lines(Remaining, Acc#{blocked_countries => Countries});
        {key, <<"allowed_countries">>, _} ->
            {Countries, Remaining} = parse_yaml_list(Rest),
            parse_yaml_lines(Remaining, Acc#{allowed_countries => Countries});
        {key, <<"ip_overrides">>, _} ->
            {Overrides, Remaining} = parse_ip_overrides(Rest),
            parse_yaml_lines(Remaining, Acc#{ip_overrides => Overrides});
        _ ->
            parse_yaml_lines(Rest, Acc)
    end.

parse_yaml_line(Line) ->
    Trimmed = string:trim(binary_to_list(Line)),
    case Trimmed of
        "" -> skip;
        [$# | _] -> skip;  %% Comment
        _ ->
            case string:split(Trimmed, ":") of
                [Key, Value] ->
                    K = list_to_binary(string:trim(Key)),
                    V = list_to_binary(string:trim(Value)),
                    {key, K, V};
                _ ->
                    skip
            end
    end.

parse_yaml_list(Lines) ->
    parse_yaml_list(Lines, []).

parse_yaml_list([], Acc) ->
    {lists:reverse(Acc), []};
parse_yaml_list([Line | Rest] = All, Acc) ->
    Trimmed = string:trim(binary_to_list(Line)),
    case Trimmed of
        [$- | Item] ->
            %% List item
            Value = list_to_binary(string:trim(Item)),
            parse_yaml_list(Rest, [Value | Acc]);
        "" ->
            %% Empty line, continue
            parse_yaml_list(Rest, Acc);
        [$# | _] ->
            %% Comment, continue
            parse_yaml_list(Rest, Acc);
        _ ->
            %% Not a list item, end of list
            {lists:reverse(Acc), All}
    end.

parse_ip_overrides(Lines) ->
    parse_ip_overrides(Lines, #{allow => [], deny => []}).

parse_ip_overrides([], Acc) ->
    {Acc, []};
parse_ip_overrides([Line | Rest] = All, Acc) ->
    Trimmed = string:trim(binary_to_list(Line)),
    case Trimmed of
        "allow:" ->
            {AllowList, Remaining} = parse_yaml_list(Rest),
            parse_ip_overrides(Remaining, Acc#{allow => AllowList});
        "deny:" ->
            {DenyList, Remaining} = parse_yaml_list(Rest),
            parse_ip_overrides(Remaining, Acc#{deny => DenyList});
        "" ->
            parse_ip_overrides(Rest, Acc);
        [$# | _] ->
            parse_ip_overrides(Rest, Acc);
        [$  | _] ->
            %% Indented, still in ip_overrides section
            parse_ip_overrides(Rest, Acc);
        _ ->
            %% Not part of ip_overrides, end
            {Acc, All}
    end.

%% @private Default configuration (blocklist mode, no blocks)
default_config() ->
    #{
        mode => blocklist,
        blocked_countries => [],
        allowed_countries => [],
        ip_overrides => #{
            allow => [
                <<"192.168.0.0/16">>,
                <<"10.0.0.0/8">>,
                <<"127.0.0.0/8">>,
                <<"172.16.0.0/12">>
            ],
            deny => []
        }
    }.

%% @private Check IP against override lists
check_override(IP, Config) ->
    Overrides = maps:get(ip_overrides, Config, #{allow => [], deny => []}),
    AllowList = maps:get(allow, Overrides, []),
    DenyList = maps:get(deny, Overrides, []),

    case ip_matches_any(IP, DenyList) of
        true -> deny;
        false ->
            case ip_matches_any(IP, AllowList) of
                true -> allow;
                false -> continue
            end
    end.

%% @private Check if IP matches any CIDR in list
ip_matches_any(_IP, []) ->
    false;
ip_matches_any(IP, [CIDR | Rest]) ->
    case ip_in_cidr(IP, CIDR) of
        true -> true;
        false -> ip_matches_any(IP, Rest)
    end.

%% @private Check if IP is in CIDR range
ip_in_cidr(IP, CIDR) when is_binary(CIDR) ->
    ip_in_cidr(IP, binary_to_list(CIDR));
ip_in_cidr(IP, CIDR) when is_list(CIDR) ->
    case string:split(CIDR, "/") of
        [NetStr, MaskStr] ->
            case inet:parse_address(NetStr) of
                {ok, Network} ->
                    Mask = list_to_integer(MaskStr),
                    ip_matches_network(IP, Network, Mask);
                {error, _} ->
                    false
            end;
        [IPStr] ->
            %% Single IP, not CIDR
            case inet:parse_address(IPStr) of
                {ok, SingleIP} -> IP =:= SingleIP;
                {error, _} -> false
            end
    end.

%% @private Check if IP matches network with mask
ip_matches_network(IP, Network, Mask) when tuple_size(IP) =:= 4, tuple_size(Network) =:= 4 ->
    %% IPv4
    IPInt = ip4_to_int(IP),
    NetInt = ip4_to_int(Network),
    MaskInt = (16#FFFFFFFF bsl (32 - Mask)) band 16#FFFFFFFF,
    (IPInt band MaskInt) =:= (NetInt band MaskInt);
ip_matches_network(IP, Network, Mask) when tuple_size(IP) =:= 8, tuple_size(Network) =:= 8 ->
    %% IPv6
    IPInt = ip6_to_int(IP),
    NetInt = ip6_to_int(Network),
    MaskInt = (16#FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF bsl (128 - Mask)) band 16#FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    (IPInt band MaskInt) =:= (NetInt band MaskInt);
ip_matches_network(_, _, _) ->
    %% Mismatched IP versions
    false.

%% @private Convert IPv4 tuple to integer
ip4_to_int({A, B, C, D}) ->
    (A bsl 24) bor (B bsl 16) bor (C bsl 8) bor D.

%% @private Convert IPv6 tuple to integer
ip6_to_int({A, B, C, D, E, F, G, H}) ->
    (A bsl 112) bor (B bsl 96) bor (C bsl 80) bor (D bsl 64) bor
    (E bsl 48) bor (F bsl 32) bor (G bsl 16) bor H.

%% @private Get file modification time
get_file_mtime(Filename) ->
    case file:read_file_info(Filename) of
        {ok, #file_info{mtime = Mtime}} -> Mtime;
        {error, _} -> undefined
    end.
