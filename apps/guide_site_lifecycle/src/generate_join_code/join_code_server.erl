%%% @doc Join code server — generates self-contained join tokens.
%%%
%%% A join token is a base64-encoded payload containing everything a new
%%% node needs to join the site: cookie, site_id, peers, realm.
%%% No callback to the admin node required during install.
%%%
%%% The token is:
%%% - Self-contained (all config embedded)
%%% - Time-limited (expires in 5 minutes)
%%% - Single-use (tracked by display code)
%%% - Signed with HMAC-SHA256 (cookie is the key)
%%%
%%% The display code (e.g., "A3X-7K2") is for the admin to verify
%%% which token was used. The actual token is the long base64 string
%%% passed to the install script.
%%% @end
-module(join_code_server).
-behaviour(gen_server).

-export([start_link/0]).
-export([generate/0, decode_token/1, list_active/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(TABLE, join_codes).
-define(CODE_LENGTH, 6).
-define(TTL_SECONDS, 300).          %% 5 minutes
-define(CLEANUP_INTERVAL, 60_000).  %% check every minute
-define(ALPHABET, "ABCDEFGHJKLMNPQRSTUVWXYZ23456789").

-record(join_record, {
    display_code :: binary(),
    created_at   :: integer(),
    expires_at   :: integer(),
    used         :: boolean()
}).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Generate a new join token. Returns display code + full token.
-spec generate() -> {ok, #{display_code := binary(), token := binary(), expires_in := integer()}}.
generate() ->
    gen_server:call(?MODULE, generate).

%% @doc Decode and verify a join token (no server call needed — self-contained).
%% Returns the site config if valid, or error.
-spec decode_token(binary()) -> {ok, map()} | {error, term()}.
decode_token(Token) ->
    decode_and_verify(Token).

%% @doc List active (non-expired, non-used) display codes.
-spec list_active() -> [map()].
list_active() ->
    gen_server:call(?MODULE, list_active).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    ?TABLE = ets:new(?TABLE, [named_table, set, {keypos, #join_record.display_code}]),
    erlang:send_after(?CLEANUP_INTERVAL, self(), cleanup),
    {ok, #{}}.

handle_call(generate, _From, State) ->
    DisplayCode = generate_display_code(),
    FormattedCode = format_code(DisplayCode),
    Now = erlang:system_time(second),
    ExpiresAt = Now + ?TTL_SECONDS,

    %% Track for single-use enforcement
    Record = #join_record{
        display_code = DisplayCode,
        created_at = Now,
        expires_at = ExpiresAt,
        used = false
    },
    ets:insert(?TABLE, Record),

    %% Build self-contained token
    Token = build_token(DisplayCode, ExpiresAt),

    logger:info("[join_code] Generated: ~s (expires in ~bs)", [FormattedCode, ?TTL_SECONDS]),
    {reply, {ok, #{
        display_code => FormattedCode,
        token => Token,
        expires_in => ?TTL_SECONDS
    }}, State};

handle_call(list_active, _From, State) ->
    Now = erlang:system_time(second),
    Active = ets:foldl(fun(#join_record{display_code = C, expires_at = Exp,
                                         used = false, created_at = Created}, Acc)
                           when Exp > Now ->
        Remaining = Exp - Now,
        [#{display_code => format_code(C), expires_in => Remaining, created_at => Created} | Acc];
    (_, Acc) -> Acc
    end, [], ?TABLE),
    {reply, Active, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(cleanup, State) ->
    Now = erlang:system_time(second),
    Expired = ets:foldl(fun(#join_record{display_code = C, expires_at = Exp, used = Used}, Acc) ->
        case Used orelse (Now > Exp) of
            true -> [C | Acc];
            false -> Acc
        end
    end, [], ?TABLE),
    lists:foreach(fun(C) -> ets:delete(?TABLE, C) end, Expired),
    erlang:send_after(?CLEANUP_INTERVAL, self(), cleanup),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

%%%===================================================================
%%% Token building
%%%===================================================================

%% @private Build a self-contained, signed token.
%% Format: base64(json_payload + "." + hmac_signature)
build_token(DisplayCode, ExpiresAt) ->
    Cookie = atom_to_binary(erlang:get_cookie()),
    SiteId = guide_site_lifecycle_app:site_id(),
    NodeName = atom_to_binary(node()),
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Bootstrap = application:get_env(hecate, mesh_bootstrap, <<"https://boot.macula.io:443">>),

    %% Extract hostname from node name for peers
    AdminHost = case binary:split(NodeName, <<"@">>) of
        [_, Host] -> Host;
        _ -> <<"localhost">>
    end,

    Payload = json:encode(#{
        cookie => Cookie,
        site_id => SiteId,
        admin_node => NodeName,
        admin_host => AdminHost,
        realm => Realm,
        bootstrap => Bootstrap,
        display_code => DisplayCode,
        expires_at => ExpiresAt
    }),

    Signature = crypto:mac(hmac, sha256, Cookie, Payload),
    SignatureHex = binary:encode_hex(Signature),

    %% Token = base64(payload.signature)
    Combined = <<Payload/binary, ".", SignatureHex/binary>>,
    base64:encode(Combined).

%%%===================================================================
%%% Token decoding (static — no server call needed)
%%%===================================================================

%% @private Decode and verify a token.
decode_and_verify(Token) ->
    case catch base64:decode(Token) of
        {'EXIT', _} -> {error, invalid_token};
        Combined ->
            case binary:split(Combined, <<".">>) of
                [Payload, SignatureHex] ->
                    verify_and_extract(Payload, SignatureHex);
                _ ->
                    {error, malformed_token}
            end
    end.

verify_and_extract(Payload, SignatureHex) ->
    case catch json:decode(Payload) of
        {'EXIT', _} -> {error, invalid_json};
        #{<<"cookie">> := Cookie} = Config ->
            %% Verify HMAC signature using the cookie from the payload
            Expected = binary:encode_hex(crypto:mac(hmac, sha256, Cookie, Payload)),
            case Expected =:= SignatureHex of
                false -> {error, invalid_signature};
                true -> verify_expiry(Config)
            end;
        _ ->
            {error, missing_cookie}
    end.

verify_expiry(#{<<"expires_at">> := ExpiresAt} = Config) ->
    Now = erlang:system_time(second),
    case Now > ExpiresAt of
        true -> {error, token_expired};
        false -> {ok, Config}
    end;
verify_expiry(Config) ->
    {ok, Config}.

%%%===================================================================
%%% Internal
%%%===================================================================

generate_display_code() ->
    Chars = ?ALPHABET,
    Len = length(Chars),
    Code = [lists:nth(rand:uniform(Len), Chars) || _ <- lists:seq(1, ?CODE_LENGTH)],
    list_to_binary(Code).

format_code(Code) when byte_size(Code) =:= ?CODE_LENGTH ->
    <<A:3/binary, B:3/binary>> = Code,
    <<A/binary, "-", B/binary>>;
format_code(Code) ->
    Code.
