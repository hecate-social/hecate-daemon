%%% @doc Merged projection: recipient-side share-license lifecycle ->
%%% `my_accepted_share_licenses` ETS (keyed by file_id).
%%%
%%% A recipient daemon accepts AT MOST one share-license per file it
%%% has been granted access to — so file_id is a stable primary key
%%% on this side. Phase F's open-path guard queries this index by
%%% file_id to find the license authorising decryption.
%%%
%%% Folds:
%%%   - `license_accepted_v1`         -> insert entry, status carries
%%%                                      SL_ACCEPTED | SL_CEK_USABLE.
%%%   - `license_ended_v1`            -> clear SL_CEK_USABLE, set
%%%                                      SL_ENDED, record end_reason +
%%%                                      ended_at. (Row stays for
%%%                                      audit / future reconciliation.)
%%%   - `license_rewrap_received_v1`  -> bump wrapped_cek +
%%%                                      k_realm_version + set
%%%                                      SL_REWRAPPED. The sealed
%%%                                      plaintext CEK
%%%                                      (`accepted_cek_sealed`) is
%%%                                      untouched.
%%%
%%% Entries mirror a subset of `accepted_license_state` — enough for
%%% the guard + open-path without re-loading the aggregate.
%%% @end
-module(share_license_lifecycle_to_accepted_index).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

%% Mirror of share_license_status.hrl bits we care about here.
%% Duplicated deliberately: project_share_licenses is a read-model app
%% that reads from guide_share_license_lifecycle's event types. We
%% include its hrl for the real defines.
-include_lib("guide_share_license_lifecycle/include/share_license_status.hrl").

-define(TABLE, my_accepted_share_licenses).

interested_in() ->
    [<<"license_accepted_v1">>,
     <<"license_ended_v1">>,
     <<"license_rewrap_received_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(Event, _Metadata, State, RM) ->
    Data = extract_data(Event),
    case event_type(Event) of
        <<"license_accepted_v1">>        -> project_accepted(Data, State, RM);
        <<"license_ended_v1">>           -> project_ended(Data, State, RM);
        <<"license_rewrap_received_v1">> -> project_rewrapped(Data, State, RM);
        _                                -> {ok, State, RM}
    end.

%%====================================================================
%% Folds
%%====================================================================

project_accepted(Data, State, RM) ->
    case gf(file_id, Data) of
        undefined -> {ok, State, RM};
        FileId ->
            Status = evoq_bit_flags:set(
                evoq_bit_flags:set(0, ?SL_ACCEPTED),
                ?SL_CEK_USABLE),
            Entry = #{
                file_id             => FileId,
                license_id          => gf(license_id, Data),
                grantee             => gf(grantee, Data),
                wrap_strategy       => to_atom(gf(wrap_strategy, Data)),
                wrapped_cek         => gf(wrapped_cek, Data),
                accepted_cek_sealed => gf(accepted_cek_sealed, Data),
                k_realm_version     => gf(k_realm_version, Data),
                issuer_did          => gf(issuer_did, Data),
                realm               => gf(realm, Data),
                issued_at           => gf(issued_at, Data),
                accepted_at         => gf(accepted_at, Data),
                expires_at          => gf(expires_at, Data),
                status              => Status,
                ended_at            => undefined,
                end_reason          => undefined
            },
            {ok, RM2} = evoq_read_model:put(FileId, Entry, RM),
            {ok, State, RM2}
    end.

project_ended(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case LicenseId of
        undefined -> {ok, State, RM};
        _ ->
            case find_by_license_id(LicenseId) of
                {ok, FileId, Existing} ->
                    Status = maps:get(status, Existing, 0),
                    Cleared = evoq_bit_flags:unset(Status, ?SL_CEK_USABLE),
                    NewStatus = evoq_bit_flags:set(Cleared, ?SL_ENDED),
                    Updated = Existing#{
                        status     => NewStatus,
                        ended_at   => gf(ended_at, Data),
                        end_reason => to_atom(gf(reason, Data))
                    },
                    {ok, RM2} = evoq_read_model:put(FileId, Updated, RM),
                    {ok, State, RM2};
                not_found ->
                    {ok, State, RM}
            end
    end.

project_rewrapped(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    NewVersion = gf(new_k_realm_version, Data),
    case {LicenseId, NewVersion} of
        {undefined, _} -> {ok, State, RM};
        {_, undefined} -> {ok, State, RM};
        _ ->
            case find_by_license_id(LicenseId) of
                {ok, FileId, Existing} ->
                    Status = maps:get(status, Existing, 0),
                    NewStatus = evoq_bit_flags:set(Status, ?SL_REWRAPPED),
                    Updated = Existing#{
                        status          => NewStatus,
                        wrapped_cek     => gf(new_wrapped_cek, Data,
                                              maps:get(wrapped_cek, Existing, <<>>)),
                        k_realm_version => NewVersion
                    },
                    {ok, RM2} = evoq_read_model:put(FileId, Updated, RM),
                    {ok, State, RM2};
                not_found ->
                    {ok, State, RM}
            end
    end.

%%====================================================================
%% Internal
%%====================================================================

event_type(#{event_type := T}) -> T;
event_type(#{<<"event_type">> := T}) -> T;
event_type(_) -> undefined.

extract_data(#{data := D}) when is_map(D) -> D;
extract_data(E) when is_map(E) -> E;
extract_data(_) -> #{}.

%% @private Find the ETS row for a given license_id. The index is
%% keyed by file_id (1:1 with license_id on the recipient side), so a
%% linear scan is the simplest answer. At recipient scale (hundreds
%% of accepted licenses) this is fast enough. Rebuild to a secondary
%% index only if profiling shows it matters.
find_by_license_id(LicenseId) ->
    case ets:whereis(?TABLE) of
        undefined -> not_found;
        _ ->
            find_row(ets:tab2list(?TABLE), LicenseId)
    end.

find_row([], _LicenseId) ->
    not_found;
find_row([{FileId, #{license_id := LicenseId} = Entry} | _], LicenseId) ->
    {ok, FileId, Entry};
find_row([_ | Rest], LicenseId) ->
    find_row(Rest, LicenseId).

gf(K, M) -> gf(K, M, undefined).
gf(K, M, Default) when is_map(M) ->
    case maps:find(K, M) of
        {ok, V} -> V;
        error ->
            case is_atom(K) of
                true  -> maps:get(atom_to_binary(K, utf8), M, Default);
                false -> Default
            end
    end;
gf(_, _, Default) -> Default.

to_atom(A) when is_atom(A)   -> A;
to_atom(B) when is_binary(B) -> try binary_to_existing_atom(B, utf8) catch _:_ -> undefined end;
to_atom(_)                   -> undefined.
