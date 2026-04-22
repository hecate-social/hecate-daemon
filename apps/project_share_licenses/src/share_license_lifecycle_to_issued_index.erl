%%% @doc Merged projection: share-license lifecycle events ->
%%% `my_issued_realm_scoped_active_licenses` ETS.
%%%
%%% Only tracks realm-scope licenses (wrap_strategy = realm_key_v1) —
%%% DID-scope licenses don't participate in rewrap since their CEKs are
%%% wrapped with the grantee's X25519 key, not K_realm.
%%%
%%% Folds:
%%%   - `license_issued_v1` (realm-scope)       -> insert entry
%%%   - `share_license_revoked_v1`              -> delete entry
%%%   - `license_rewrapped_v1`                  -> update version +
%%%                                                wrapped_cek + bump
%%%                                                rewrap timestamp
%%%
%%% Read-after-rotation semantics: the PM queries for
%%% `{Realm, OldVersion}` after having processed its own local
%%% `realm_shared_key_stored_v1`; because this projection and the
%%% `realm_shared_keys` table advance monotonically and the PM acts on
%%% the NEW version's stored event, the OLD version's entries are still
%%% in the table when the PM reads them (rewrap events haven't fired
%%% yet — the PM is what triggers them).
%%% @end
-module(share_license_lifecycle_to_issued_index).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

-define(TABLE, my_issued_realm_scoped_active_licenses).

interested_in() ->
    [<<"license_issued_v1">>,
     <<"share_license_revoked_v1">>,
     <<"license_rewrapped_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(Event, _Metadata, State, RM) ->
    Data = extract_data(Event),
    case event_type(Event) of
        <<"license_issued_v1">>        -> project_issued(Data, State, RM);
        <<"share_license_revoked_v1">> -> project_revoked(Data, State, RM);
        <<"license_rewrapped_v1">>     -> project_rewrapped(Data, State, RM);
        _                              -> {ok, State, RM}
    end.

%%====================================================================
%% Folds
%%====================================================================

project_issued(Data, State, RM) ->
    case to_atom(gf(wrap_strategy, Data)) of
        realm_key_v1 -> insert_issued(Data, State, RM);
        _            -> {ok, State, RM}  %% DID-scope: ignore
    end.

insert_issued(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case LicenseId of
        undefined ->
            {ok, State, RM};
        _ ->
            Entry = #{
                license_id        => LicenseId,
                realm             => gf(realm, Data),
                k_realm_version   => gf(k_realm_version, Data),
                wrap_strategy     => realm_key_v1,
                wrapped_cek       => gf(wrapped_cek, Data),
                origin_cek_sealed => gf(origin_cek_sealed, Data),
                issuer_did        => gf(issuer_did, Data),
                grantee           => gf(grantee, Data),
                issued_at         => gf(issued_at, Data),
                rewrapped_at      => undefined
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Entry, RM),
            {ok, State, RM2}
    end.

project_revoked(Data, State, RM) ->
    case gf(license_id, Data) of
        undefined -> {ok, State, RM};
        LicenseId ->
            {ok, RM2} = evoq_read_model:delete(LicenseId, RM),
            {ok, State, RM2}
    end.

project_rewrapped(Data, State, RM) ->
    LicenseId = gf(license_id, Data),
    case {LicenseId, gf(new_k_realm_version, Data)} of
        {undefined, _} -> {ok, State, RM};
        {_, undefined} -> {ok, State, RM};
        {LicenseId, NewV} ->
            case ets:lookup(?TABLE, LicenseId) of
                [{_, Existing}] ->
                    Updated = Existing#{
                        k_realm_version => NewV,
                        wrapped_cek     => gf(new_wrapped_cek, Data,
                                              maps:get(wrapped_cek, Existing, <<>>)),
                        rewrapped_at    => gf(rewrapped_at, Data)
                    },
                    {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
                    {ok, State, RM2};
                [] ->
                    %% Rewrap for a license we never tracked — could
                    %% happen on historical replay of an issue we
                    %% filtered out (DID-scope). Safe to ignore.
                    {ok, State, RM}
            end
    end.

%%====================================================================
%% Internal
%%====================================================================

event_type(#{event_type := T}) -> T;
event_type(_) -> undefined.

extract_data(#{data := D}) when is_map(D) -> D;
extract_data(E) when is_map(E) -> E;
extract_data(_) -> #{}.

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
