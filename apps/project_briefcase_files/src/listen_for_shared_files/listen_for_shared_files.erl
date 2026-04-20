%%% @doc Mesh subscriber for `<realm>.briefcase.file_shared` facts.
%%%
%%% When another peer in the realm publishes a `file_shared_v1` fact,
%%% this process:
%%%   1. skips the fact if we already have the file locally
%%%   2. fetches content via `<realm>.briefcase.get_chunk` RPC
%%%   3. writes content to the local briefcase_content_store
%%%   4. inserts the metadata into the briefcase_files ETS so the UI
%%%      shows the new file immediately
%%%
%%% Phase 2 (this PR): whole-file fetch per fact, no retry queue.
%%% Phase 3+: chunk-level parallel fetch, fallback to other peers,
%%% signed-chunk verification, resume-on-reconnect.
%%% @end
-module(listen_for_shared_files).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RPC_TIMEOUT_MS, 30000).

-record(state, {
    realm   :: binary(),
    topic   :: binary(),
    rpc     :: binary()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Topic = <<Realm/binary, ".briefcase.file_shared">>,
    Rpc   = <<Realm/binary, ".briefcase.get_chunk">>,
    Self  = self(),
    Callback = fun(Fact) ->
        Self ! {shared_fact, Fact},
        ok
    end,
    hecate_mesh_client:register_subscription(Topic, Callback),
    logger:info("[briefcase] subscribed to mesh topic ~s", [Topic]),
    {ok, #state{realm = Realm, topic = Topic, rpc = Rpc}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)        -> {noreply, State}.

handle_info({shared_fact, Fact}, State) ->
    _ = process_fact(Fact, State),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.

%%% ===================================================================
%%% Internal
%%% ===================================================================

process_fact(Fact, State) ->
    case extract_file_id(Fact) of
        {ok, FileId} ->
            case project_briefcase_files_store:get(FileId) of
                {ok, _Entry} ->
                    %% Already seen — idempotent re-delivery
                    ok;
                {error, not_found} ->
                    fetch_and_store(FileId, Fact, State)
            end;
        {error, _} = E ->
            logger:warning("[briefcase] malformed shared fact: ~p", [Fact]),
            E
    end.

fetch_and_store(FileId, Fact, #state{rpc = Rpc}) ->
    case hecate_mesh_client:get_client() of
        {ok, Client} when is_pid(Client) ->
            Args = #{file_id => FileId},
            case macula:call(Client, Rpc, Args, ?RPC_TIMEOUT_MS) of
                {ok, #{<<"bytes">> := Bytes} = _Reply} ->
                    finalize(FileId, Bytes, Fact);
                {ok, #{bytes := Bytes}} ->
                    finalize(FileId, Bytes, Fact);
                {ok, Other} ->
                    logger:warning("[briefcase] unexpected RPC reply for ~s: ~p",
                                   [FileId, Other]),
                    {error, bad_reply};
                {error, Reason} ->
                    logger:warning("[briefcase] RPC ~s failed for ~s: ~p",
                                   [Rpc, FileId, Reason]),
                    {error, Reason}
            end;
        _ ->
            logger:warning("[briefcase] mesh not activated; cannot fetch ~s",
                           [FileId]),
            {error, mesh_not_activated}
    end.

finalize(FileId, Bytes, Fact) ->
    ok = briefcase_content_store:put(FileId, Bytes),
    Entry = fact_to_entry(Fact),
    ets:insert(briefcase_files, {FileId, Entry}),
    logger:info("[briefcase] received shared file ~s (~b bytes)",
                [FileId, byte_size(Bytes)]),
    ok.

%%% --- Helpers ------------------------------------------------------

extract_file_id(#{<<"file_id">> := FileId}) when is_binary(FileId) -> {ok, FileId};
extract_file_id(#{file_id     := FileId}) when is_binary(FileId) -> {ok, FileId};
extract_file_id(_)                                               -> {error, no_file_id}.

fact_to_entry(Fact) ->
    #{
        file_id      => gf(file_id, Fact),
        realm        => gf(realm, Fact),
        path         => gf(path, Fact),
        mime_type    => gf(mime_type, Fact),
        size         => gf(size, Fact),
        content_hash => gf(content_hash, Fact),
        author_did   => gf(author_did, Fact),
        uploaded_at  => gf(shared_at, Fact),
        status       => 1,
        status_label => <<"Shared">>
    }.

gf(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, undefined)
    end.
