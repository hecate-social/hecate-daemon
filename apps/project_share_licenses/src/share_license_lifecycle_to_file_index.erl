%%% @doc Projection: `license_issued_v1` -> `my_issued_files` ETS.
%%%
%%% One entry per file the issuer has shared, capturing the
%%% `origin_cek_sealed` (issuer's sealed copy of the per-file CEK) so
%%% the serve path can unwrap + encrypt content without loading an
%%% aggregate or scanning multiple license rows.
%%%
%%% Why per-file, not per-license:
%%%
%%%   `issue_licenses_for_share` mints ONE CEK per file and wraps it
%%%   N times for N recipients — each resulting `license_issued_v1`
%%%   event carries the SAME `origin_cek_sealed` bytes. A single-row
%%%   index per file_id is all the serve path needs.
%%%
%%% Insert is idempotent: replaying an issue event for an already-
%%% tracked file keeps the existing row. If the sealed bytes somehow
%%% differ (which would be a bug), we log but keep the original.
%%% @end
-module(share_license_lifecycle_to_file_index).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

-define(TABLE, my_issued_files).

interested_in() ->
    [<<"license_issued_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(Event, _Metadata, State, RM) ->
    Data = extract_data(Event),
    FileId = gf(file_id, Data),
    OriginSealed = gf(origin_cek_sealed, Data),
    case {FileId, OriginSealed} of
        {undefined, _}   -> {ok, State, RM};
        {_, undefined}   -> {ok, State, RM};
        {_, <<>>}        -> {ok, State, RM};
        _                -> insert_if_absent(FileId, OriginSealed, Data, State, RM)
    end.

%%====================================================================
%% Internal
%%====================================================================

insert_if_absent(FileId, OriginSealed, Data, State, RM) ->
    case ets:whereis(?TABLE) of
        undefined ->
            %% Table not yet created — skip. On replay after restart
            %% the projection init will create the table and re-run.
            {ok, State, RM};
        _ ->
            case ets:lookup(?TABLE, FileId) of
                [{_, #{origin_cek_sealed := Existing}}]
                  when Existing =:= OriginSealed ->
                    {ok, State, RM};
                [{_, #{origin_cek_sealed := _Different}}] ->
                    logger:warning(
                        "[share_license_to_file_index] ignoring mismatched "
                        "origin_cek_sealed for file=~s — keeping original",
                        [FileId]),
                    {ok, State, RM};
                [] ->
                    Entry = #{
                        file_id           => FileId,
                        origin_cek_sealed => OriginSealed,
                        realm             => gf(realm, Data),
                        issuer_did        => gf(issuer_did, Data),
                        first_issued_at   => gf(issued_at, Data)
                    },
                    {ok, RM2} = evoq_read_model:put(FileId, Entry, RM),
                    {ok, State, RM2}
            end
    end.

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
