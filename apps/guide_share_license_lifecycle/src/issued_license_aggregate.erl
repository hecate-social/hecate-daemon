%%% @doc Issuer-side share-license aggregate.
%%%
%%% One aggregate per license_id the ISSUER minted. Stream:
%%% `issued-license-{license_id}`. Store: `share_licenses_store`.
%%%
%%% Lifecycle:
%%%   1. issue_license_v1 (birth — carries file_id, grantee, wrapped_cek,
%%%      origin_cek_sealed for future rewrap).
%%%   2. revoke_license_v1 — Session 3 (issuer revokes a specific grant).
%%%   3. rewrap_license_v1 — Session 4 (after K_realm rotation).
%%%
%%% Phase D Session 2 covers birth only. State module already folds the
%%% future events so replay works across versions.
%%% @end
-module(issued_license_aggregate).
-behaviour(evoq_aggregate).

-include("share_license_status.hrl").
-include("issued_license_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/1, flag_map/0]).

-type state() :: #issued_license_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> issued_license_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?SL_FLAG_MAP.

-spec stream_id(binary()) -> binary().
stream_id(LicenseId) when is_binary(LicenseId) ->
    <<"issued-license-", LicenseId/binary>>.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) -> {ok, issued_license_state:new(AggregateId)}.

%% NOTE: evoq calls execute(State, Payload) — State FIRST.

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only issue allowed.
execute(#issued_license_state{status = 0}, Payload) ->
    case command_type(Payload) of
        issue_license_v1 -> maybe_issue_license:handle_from_map(Payload);
        _                -> {error, license_not_issued}
    end;

%% Already revoked — terminal.
execute(#issued_license_state{status = S}, _Payload)
  when S band ?SL_REVOKED =/= 0 ->
    {error, license_revoked};

%% Issued + active — accept issue (reject) / revoke / rewrap (Session 4).
execute(#issued_license_state{status = S} = State, Payload)
  when S band ?SL_ISSUED =/= 0 ->
    case command_type(Payload) of
        issue_license_v1         -> {error, already_issued};
        revoke_share_license_v1  -> maybe_revoke_share_license:handle_from_map(
                                        enrich_from_state(Payload, State));
        _                        -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Apply ---

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    issued_license_state:apply_event(State, Event).

%% --- Internal ---

command_type(#{command_type := T}) when is_atom(T) -> T;
command_type(#{command_type := T}) when is_binary(T) -> binary_to_existing_atom(T, utf8);
command_type(_) -> undefined.

%% @private Enrich the revoke payload with fields already on state so the
%% mesh FACT can carry grantee / realm / issuer_did without the caller
%% needing to know them.
enrich_from_state(Payload, #issued_license_state{} = S) ->
    Defaults = #{
        license_id => S#issued_license_state.license_id,
        grantee    => S#issued_license_state.grantee,
        realm      => S#issued_license_state.realm,
        issuer_did => S#issued_license_state.issuer_did
    },
    maps:merge(Defaults, Payload).
