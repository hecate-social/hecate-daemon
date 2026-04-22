%%% @doc Recipient-side share-license aggregate.
%%%
%%% One aggregate per license_id the RECIPIENT accepted. Stream:
%%% `accepted-license-{license_id}`. Store: `share_licenses_store`.
%%%
%%% Lifecycle:
%%%   1. accept_license_v1 (birth — recipient unwraps wrapped_cek,
%%%      seals plaintext CEK via hecate_crypto, stores as
%%%      accepted_cek_sealed).
%%%   2. end_license_v1 (after observing revoke fact or receiving
%%%      membership end; clears CEK_USABLE).
%%%   3. receive_license_rewrap_v1 — Session 4 (updates wrapped_cek
%%%      metadata after K_realm rotation; plaintext CEK unchanged).
%%% @end
-module(accepted_license_aggregate).
-behaviour(evoq_aggregate).

-include("share_license_status.hrl").
-include("accepted_license_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/1, flag_map/0]).

-type state() :: #accepted_license_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> accepted_license_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?SL_FLAG_MAP.

-spec stream_id(binary()) -> binary().
stream_id(LicenseId) when is_binary(LicenseId) ->
    <<"accepted-license-", LicenseId/binary>>.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) -> {ok, accepted_license_state:new(AggregateId)}.

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh — only accept allowed.
execute(#accepted_license_state{status = 0}, Payload) ->
    case command_type(Payload) of
        accept_license_v1 -> maybe_accept_license:handle_from_map(Payload);
        _                 -> {error, license_not_accepted}
    end;

%% Ended — terminal.
execute(#accepted_license_state{status = S}, _Payload)
  when S band ?SL_ENDED =/= 0 ->
    {error, license_ended};

%% Accepted — end allowed. Double-accept rejected.
execute(#accepted_license_state{status = S}, Payload)
  when S band ?SL_ACCEPTED =/= 0 ->
    case command_type(Payload) of
        accept_license_v1 -> {error, already_accepted};
        end_license_v1    -> maybe_end_license:handle_from_map(Payload);
        _                 -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Apply ---

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    accepted_license_state:apply_event(State, Event).

%% --- Internal ---

command_type(#{command_type := T}) when is_atom(T) -> T;
command_type(#{command_type := T}) when is_binary(T) -> binary_to_existing_atom(T, utf8);
command_type(_) -> undefined.
