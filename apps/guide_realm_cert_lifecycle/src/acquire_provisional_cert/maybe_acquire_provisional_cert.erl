%%% @doc Handler for acquire_provisional_cert_v1.
%%%
%%% Reads the daemon's pubkey from `hecate_identity', POSTs it to the
%%% realm's `/api/v1/provisional/issue' endpoint, writes the returned
%%% bundle (cert + key + CA chain) to disk under `CertDir', and
%%% produces a `provisional_cert_acquired_v1' event recording the
%%% metadata + paths. The PEMs stay on disk so secrets never enter
%%% the event store.
%%%
%%% File permissions: cert.pem and chain.pem 0644, key.pem 0600.
%%% Directory: 0700.
%%% @end
-module(maybe_acquire_provisional_cert).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1, handle_from_map/1]}).

-include_lib("evoq/include/evoq.hrl").

-define(REQUEST_TIMEOUT_MS, 30000).

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{realm_url := RealmUrl, cert_dir := CertDir} = Payload)
  when is_binary(RealmUrl), is_binary(CertDir) ->
    RequestedAt = maps:get(requested_at, Payload, erlang:system_time(millisecond)),
    Cmd = acquire_provisional_cert_v1:new(RealmUrl, CertDir, RequestedAt),
    handle(Cmd);
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(acquire_provisional_cert_v1:acquire_provisional_cert_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{realm_url := RealmUrl, cert_dir := CertDir}
        = acquire_provisional_cert_v1:to_map(Command),
    case acquire(RealmUrl, CertDir) of
        {ok, Event} ->
            {ok, [provisional_cert_acquired_v1:to_map(Event)]};
        {error, _} = Err ->
            Err
    end.

%%--------------------------------------------------------------------
%% Acquisition pipeline
%%--------------------------------------------------------------------

acquire(RealmUrl, CertDir) ->
    case daemon_pubkey() of
        {ok, Pubkey} ->
            case post_issue(RealmUrl, Pubkey) of
                {ok, Bundle} ->
                    persist(Bundle, CertDir);
                {error, _} = Err ->
                    Err
            end;
        {error, _} = Err ->
            Err
    end.

daemon_pubkey() ->
    case erlang:function_exported(hecate_identity, agent_id, 0) of
        false ->
            {error, no_identity_module};
        true ->
            try hecate_identity:agent_id() of
                {ok, Bin} when is_binary(Bin), byte_size(Bin) =:= 32 ->
                    {ok, Bin};
                Bin when is_binary(Bin), byte_size(Bin) =:= 32 ->
                    {ok, Bin};
                Other ->
                    {error, {unexpected_agent_id_shape, Other}}
            catch
                Class:Reason ->
                    {error, {agent_id_failed, Class, Reason}}
            end
    end.

post_issue(RealmUrl, Pubkey) ->
    Url = <<RealmUrl/binary, "/api/v1/provisional/issue">>,
    Body = jsx_encode_or_fallback(#{public_key => base64:encode(Pubkey)}),
    Headers = [{<<"content-type">>, <<"application/json">>}],
    Opts = [with_body, {recv_timeout, ?REQUEST_TIMEOUT_MS}],
    case hackney:post(Url, Headers, Body, Opts) of
        {ok, Status, _Hdrs, RespBody} when Status >= 200, Status < 300 ->
            decode_bundle(RespBody);
        {ok, Status, _Hdrs, RespBody} ->
            {error, {realm_http_error, Status, truncate(RespBody)}};
        {error, Reason} ->
            {error, {realm_request_failed, Reason}}
    end.

%% @private Prefer OTP's `json' (OTP 27+). Fall back to `jsx' if it's
%% on the path. We avoid a hard dep on either; the daemon already
%% encodes JSON in many places.
jsx_encode_or_fallback(Map) ->
    case erlang:function_exported(json, encode, 1) of
        true ->
            iolist_to_binary(json:encode(Map));
        false ->
            iolist_to_binary(jsx:encode(Map))
    end.

jsx_decode_or_fallback(Bin) ->
    case erlang:function_exported(json, decode, 1) of
        true ->
            json:decode(Bin);
        false ->
            jsx:decode(Bin, [return_maps])
    end.

decode_bundle(RespBody) ->
    try jsx_decode_or_fallback(RespBody) of
        #{<<"tier">> := Tier, <<"handle">> := Handle, <<"mri">> := Mri,
          <<"cert_pem">> := CertPem, <<"key_pem">> := KeyPem,
          <<"ca_chain_pem">> := CaPem, <<"expires_at">> := ExpiresIso} ->
            case parse_iso8601_ms(ExpiresIso) of
                {ok, ExpiresMs} ->
                    {ok, #{tier => Tier, handle => Handle, mri => Mri,
                           cert_pem => CertPem, key_pem => KeyPem,
                           ca_chain_pem => CaPem, expires_at_ms => ExpiresMs}};
                {error, _} = Err ->
                    Err
            end;
        Other ->
            {error, {malformed_realm_response, Other}}
    catch
        Class:Reason ->
            {error, {realm_response_decode_failed, Class, Reason}}
    end.

parse_iso8601_ms(Bin) when is_binary(Bin) ->
    try
        Str = binary_to_list(Bin),
        case calendar:rfc3339_to_system_time(Str, [{unit, millisecond}]) of
            Ms when is_integer(Ms) -> {ok, Ms}
        end
    catch
        _:_ -> {error, {invalid_expires_at, Bin}}
    end.

%%--------------------------------------------------------------------
%% Disk persistence
%%--------------------------------------------------------------------

persist(#{cert_pem := CertPem, key_pem := KeyPem, ca_chain_pem := CaPem,
          tier := Tier, handle := Handle, mri := Mri,
          expires_at_ms := ExpiresMs}, CertDir) ->
    CertDirStr = binary_to_list(CertDir),
    case filelib:ensure_dir(filename:join(CertDirStr, "marker")) of
        ok ->
            file:change_mode(CertDirStr, 8#0700),
            CertPath = filename:join(CertDirStr, "cert.pem"),
            KeyPath  = filename:join(CertDirStr, "key.pem"),
            CaPath   = filename:join(CertDirStr, "chain.pem"),
            case write_with_mode(CertPath, CertPem, 8#0644) of
                ok ->
                    case write_with_mode(KeyPath, KeyPem, 8#0600) of
                        ok ->
                            case write_with_mode(CaPath, CaPem, 8#0644) of
                                ok ->
                                    Event = provisional_cert_acquired_v1:new(
                                              Tier, Handle, Mri, ExpiresMs,
                                              list_to_binary(CertPath),
                                              list_to_binary(KeyPath),
                                              list_to_binary(CaPath)),
                                    {ok, Event};
                                {error, R} -> {error, {write_failed, CaPath, R}}
                            end;
                        {error, R} -> {error, {write_failed, KeyPath, R}}
                    end;
                {error, R} -> {error, {write_failed, CertPath, R}}
            end;
        {error, R} ->
            {error, {mkdir_failed, CertDir, R}}
    end.

write_with_mode(Path, Bytes, Mode) ->
    case file:write_file(Path, Bytes) of
        ok ->
            _ = file:change_mode(Path, Mode),
            ok;
        {error, _} = Err ->
            Err
    end.

truncate(Bin) when is_binary(Bin), byte_size(Bin) > 256 ->
    <<Head:256/binary, _/binary>> = Bin,
    Head;
truncate(Bin) when is_binary(Bin) -> Bin;
truncate(Other) -> Other.

%%--------------------------------------------------------------------
%% Dispatch
%%--------------------------------------------------------------------

-spec dispatch(acquire_provisional_cert_v1:acquire_provisional_cert_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CmdMap = acquire_provisional_cert_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = acquire_provisional_cert_v1,
        aggregate_type = realm_cert_aggregate,
        aggregate_id = realm_cert_aggregate:stream_id(),
        payload = CmdMap#{command_type => acquire_provisional_cert_v1},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => realm_cert_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
