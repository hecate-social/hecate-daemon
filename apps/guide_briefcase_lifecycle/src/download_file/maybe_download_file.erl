%%% @doc Handler for download_file_v1.
%%%
%%% The user-facing "I want this file pulled down" command. Emits
%%% `file_download_started_v1` synchronously, which the PM
%%% `on_file_download_started_fetch_bytes` reacts to by spawning a
%%% supervised `briefcase_download_worker`. The cowboy request that
%%% dispatched this command returns as soon as the event is persisted
%%% — no blocking on the network pull.
%%%
%%% Gates:
%%%   - `realm` must be set on the aggregate (populated by the
%%%     file_announced_v1 birth event).
%%%   - `hecate_license_guard:can_open_file/2` must pass. No point
%%%     pulling ciphertext we can't decrypt — the guard refuses
%%%     stale / revoked / expired licenses up-front.
%%%
%%% Worker failure / success flow into the aggregate via
%%% `complete_file_download_v1` / `fail_file_download_v1` dispatched
%%% from the worker itself.
%%% @end
-module(maybe_download_file).

-export([handle_with_state/2, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").
-include("briefcase_state.hrl").

-spec handle_with_state(map(), #briefcase_state{}) ->
    {ok, [map()]} | {error, term()}.
handle_with_state(Payload, State) ->
    FileId = maps:get(file_id, Payload),
    Realm  = State#briefcase_state.realm,
    case validate_realm(Realm) of
        ok             -> guard_and_emit(FileId, Realm, State);
        {error, _} = E -> E
    end.

-spec dispatch(download_file_v1:download_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId   = download_file_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    Payload  = download_file_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = download_file_v1,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => download_file_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).

%%====================================================================
%% Internal
%%====================================================================

validate_realm(undefined) -> {error, realm_not_set};
validate_realm(R) when is_binary(R), byte_size(R) > 0 -> ok;
validate_realm(_) -> {error, realm_not_set}.

guard_and_emit(FileId, Realm, State) ->
    case hecate_license_guard:can_open_file(FileId, Realm) of
        ok ->
            {ok, Event} = file_download_started_v1:new(#{
                file_id    => FileId,
                realm      => Realm,
                issuer_did => State#briefcase_state.author_did,
                started_at => erlang:system_time(millisecond)}),
            {ok, [file_download_started_v1:to_map(Event)]};
        {error, Reason} ->
            {error, {license_refused, Reason}}
    end.
