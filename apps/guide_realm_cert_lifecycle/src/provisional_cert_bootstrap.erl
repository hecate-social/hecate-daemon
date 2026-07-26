%%% @doc First-boot provisional cert bootstrap worker.
%%%
%%% On daemon start, checks the local cert directory. If cert + key +
%%% chain are all present, no-ops and lets the daemon continue. If
%%% any are missing, dispatches `acquire_provisional_cert_v1' to
%%% trigger an HTTPS round-trip to the realm.
%%%
%%% Realm URL is configurable via `application:get_env(hecate,
%%% realm_url)' or the `MACULA_REALM_URL' env var (env wins). Default
%%% `https://macula.io'. Cert directory is `HECATE_HOME/realm-cert'.
%%%
%%% Renewal-by-expiry is a follow-up slice: this worker only checks
%%% file existence at boot. Manual delete of the cert dir forces
%%% reacquisition on the next start. A proper expiry check (parsing
%%% the cert's notAfter field) lands with the renewal-tick slice.
%%% @end
-module(provisional_cert_bootstrap).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_continue/2, handle_info/2]).

-define(DEFAULT_REALM_URL, <<"https://macula.io">>).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #{}, {continue, check_cert}}.

handle_continue(check_cert, State) ->
    CertDir = cert_dir(),
    case has_cert_on_disk(CertDir) of
        true ->
            logger:info(
                "[provisional_cert_bootstrap] cert present at ~s, skip acquisition",
                [binary_to_list(CertDir)]),
            {noreply, State};
        false ->
            RealmUrl = realm_url(),
            logger:info(
                "[provisional_cert_bootstrap] no cert at ~s, acquiring from ~s",
                [binary_to_list(CertDir), binary_to_list(RealmUrl)]),
            attempt_acquire(RealmUrl, CertDir),
            {noreply, State}
    end.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Msg, State) -> {noreply, State}.

%%--------------------------------------------------------------------
%% Config
%%--------------------------------------------------------------------

cert_dir() ->
    Base = case erlang:function_exported(shared_paths, hecate_home, 0) of
               true -> shared_paths:hecate_home();
               false ->
                   case os:getenv("HOME") of
                       false -> "/tmp";
                       Home  -> filename:join(Home, ".hecate")
                   end
           end,
    list_to_binary(filename:join(Base, "realm-cert")).

realm_url() ->
    case os:getenv("MACULA_REALM_URL") of
        false -> from_app_env();
        ""    -> from_app_env();
        EnvUrl -> list_to_binary(EnvUrl)
    end.

from_app_env() ->
    case application:get_env(hecate, realm_url, ?DEFAULT_REALM_URL) of
        Bin when is_binary(Bin) -> Bin;
        Str when is_list(Str)   -> list_to_binary(Str);
        _                       -> ?DEFAULT_REALM_URL
    end.

%%--------------------------------------------------------------------
%% Cert presence check
%%--------------------------------------------------------------------

has_cert_on_disk(CertDir) ->
    CertDirStr = binary_to_list(CertDir),
    filelib:is_regular(filename:join(CertDirStr, "cert.pem")) andalso
        filelib:is_regular(filename:join(CertDirStr, "key.pem")) andalso
        filelib:is_regular(filename:join(CertDirStr, "chain.pem")).

%%--------------------------------------------------------------------
%% Dispatch
%%--------------------------------------------------------------------

attempt_acquire(RealmUrl, CertDir) ->
    case acquire_provisional_cert_v1:new(#{realm_url => RealmUrl,
                                           cert_dir => CertDir}) of
        {ok, Cmd} ->
            case maybe_acquire_provisional_cert:dispatch(Cmd) of
                {ok, Version, _Events} ->
                    logger:info(
                        "[provisional_cert_bootstrap] acquired cert, version=~p",
                        [Version]);
                {error, Reason} ->
                    logger:warning(
                        "[provisional_cert_bootstrap] acquisition failed: ~p",
                        [Reason])
            end;
        {error, Reason} ->
            logger:warning(
                "[provisional_cert_bootstrap] invalid command: ~p", [Reason])
    end.
