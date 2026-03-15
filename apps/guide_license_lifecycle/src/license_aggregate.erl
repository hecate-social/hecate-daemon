%%% @doc Consumer license aggregate.
%%%
%%% Stream: license-{consumer_id}-{plugin_id}
%%% Store: licenses_store
%%%
%%% Lifecycle:
%%%   1. initiate_license (birth — full offering snapshot deep-copied)
%%%   2. accept_offering_terms (lightweight consent confirmation)
%%%      OR reject_offering_terms (terminal)
%%%   3. buy_license (paid path) OR free auto-grants via PM
%%%      OR abandon_license (terminal)
%%%   4. grant_license (PM auto-grants after buy or free acceptance)
%%%   5. expire_license / renew_license / revoke_license / archive_license
%%% @end
-module(license_aggregate).

-behaviour(evoq_aggregate).

-include("license_status.hrl").
-include("license_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0]).
-export([flag_map/0]).

-type state() :: #license_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> license_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?LIC_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, license_state:new(AggregateId)}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate
execute(#license_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_license">> -> execute_initiate_license(Payload);
        _ -> {error, license_not_initiated}
    end;

%% Archived — terminal, nothing allowed
execute(#license_state{status = S}, _Payload) when S band ?LIC_ARCHIVED =/= 0 ->
    {error, license_archived};

%% Revoked — only archive
execute(#license_state{status = S}, Payload) when S band ?LIC_REVOKED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, license_revoked}
    end;

%% Expired — renew or archive
execute(#license_state{status = S}, Payload) when S band ?LIC_EXPIRED =/= 0 ->
    case get_command_type(Payload) of
        <<"renew_license">>   -> execute_renew_license(Payload);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, license_expired}
    end;

%% Granted — expire, revoke, or archive
execute(#license_state{status = S}, Payload) when S band ?LIC_GRANTED =/= 0 ->
    case get_command_type(Payload) of
        <<"expire_license">>  -> execute_expire_license(Payload);
        <<"revoke_license">>  -> execute_revoke_license(Payload);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, already_granted}
    end;

%% Bought — only grant (PM dispatches this)
execute(#license_state{status = S} = State, Payload) when S band ?LIC_BOUGHT =/= 0 ->
    case get_command_type(Payload) of
        <<"grant_license">>   -> execute_grant_license(State, Payload);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, awaiting_grant}
    end;

%% Accepted — buy (paid path), abandon, or grant (free path via PM)
execute(#license_state{status = S} = State, Payload) when S band ?LIC_ACCEPTED =/= 0 ->
    case get_command_type(Payload) of
        <<"buy_license">>       -> execute_buy_license(Payload);
        <<"grant_license">>     -> execute_grant_license(State, Payload);
        <<"abandon_license">>   -> execute_abandon_license(Payload);
        <<"archive_license">>   -> execute_archive_license(Payload);
        _ -> {error, not_bought}
    end;

%% Initiated — accept or reject terms
execute(#license_state{status = S} = State, Payload) when S band ?LIC_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"accept_offering_terms">>  -> execute_accept_offering_terms(State, Payload);
        <<"reject_offering_terms">>  -> execute_reject_offering_terms(Payload);
        <<"archive_license">>        -> execute_archive_license(Payload);
        _ -> {error, not_accepted}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_license(Payload) ->
    {ok, Cmd} = initiate_license_v1:from_map(Payload),
    convert_events(maybe_initiate_license:handle(Cmd), fun license_initiated_v1:to_map/1).

execute_accept_offering_terms(State, Payload) ->
    {ok, Cmd} = accept_offering_terms_v1:from_map(Payload),
    convert_events(maybe_accept_offering_terms:handle(Cmd, State), fun offering_terms_accepted_v1:to_map/1).

execute_reject_offering_terms(Payload) ->
    {ok, Cmd} = reject_offering_terms_v1:from_map(Payload),
    convert_events(maybe_reject_offering_terms:handle(Cmd), fun offering_terms_rejected_v1:to_map/1).

execute_buy_license(Payload) ->
    {ok, Cmd} = buy_license_v1:from_map(Payload),
    convert_events(maybe_buy_license:handle(Cmd), fun license_bought_v1:to_map/1).

execute_abandon_license(Payload) ->
    {ok, Cmd} = abandon_license_v1:from_map(Payload),
    convert_events(maybe_abandon_license:handle(Cmd), fun license_abandoned_v1:to_map/1).

execute_grant_license(State, Payload) ->
    {ok, Cmd} = grant_license_v1:from_map(Payload),
    convert_events(maybe_grant_license:handle(Cmd, State), fun license_granted_v1:to_map/1).

execute_expire_license(Payload) ->
    {ok, Cmd} = expire_license_v1:from_map(Payload),
    convert_events(maybe_expire_license:handle(Cmd), fun license_expired_v1:to_map/1).

execute_renew_license(Payload) ->
    {ok, Cmd} = renew_license_v1:from_map(Payload),
    convert_events(maybe_renew_license:handle(Cmd), fun license_renewed_v1:to_map/1).

execute_revoke_license(Payload) ->
    {ok, Cmd} = revoke_license_v1:from_map(Payload),
    convert_events(maybe_revoke_license:handle(Cmd), fun license_revoked_v1:to_map/1).

execute_archive_license(Payload) ->
    {ok, Cmd} = archive_license_v1:from_map(Payload),
    convert_events(maybe_archive_license:handle(Cmd), fun license_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    license_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
