%%% @doc stream_chat_with_llm — server-stream RPC bridge.
%%%
%%% Advertises a server-stream procedure that bridges chat_to_llm's
%%% per-token provider stream onto the macula streaming RPC. Each
%%% normalized provider chunk is forwarded as a single STREAM_DATA
%%% frame (msgpack-encoded). The stream closes on llm_done; aborts
%%% on llm_error.
%%%
%%% Procedure name: <Realm>.llm.chat_stream
%%%
%%% Request shape (the open Args):
%%%   #{ <<"model">>    => binary(),
%%%      <<"messages">> => [map()],
%%%      <<"opts">>     => map() | undefined }
%%%
%%% Stream chunk shape (msgpack-encoded map per chunk):
%%%   The provider's normalize_stream_chunk/1 output. Typically:
%%%   #{ <<"delta">> => binary() | undefined,
%%%      <<"role">>  => binary() | undefined,
%%%      <<"finish_reason">> => binary() | undefined,
%%%      ... }
%%%
%%% Bridge process model: the advertise_stream handler runs in its own
%%% process (spawned by macula_stream_local / mesh_client). chat_to_llm
%%% spawns a separate provider process that sends {llm_chunk, Ref, _}
%%% messages back. The handler loops on those messages and forwards
%%% each chunk to the macula stream.
-module(stream_chat_with_llm).
-behaviour(gen_server).

-export([start_link/0, procedure/0, handle/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Generous default per-chunk timeout: large local models can be slow
%% on first token while loading into VRAM; cloud providers can stall
%% briefly behind rate limiters.
-define(IDLE_TIMEOUT_MS, 300000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Build the procedure MRI (app-tier hope).
-spec procedure() -> binary().
procedure() ->
    hecate_topics:app_hope(<<"llm">>, <<"chat_stream">>, 1).

%% @doc gen_server init — register the streaming advertisement.
init([]) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    ok = hecate_mesh_client:register_stream_advertisement(
            procedure(),
            server_stream,
            fun ?MODULE:handle/2),
    {ok, #{realm => Realm}}.

handle_call(_Request, _From, State) -> {reply, {error, unknown_call}, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%%====================================================================
%% Stream handler
%%====================================================================

%% @doc Handler invoked when a remote caller opens a streaming call
%% against this procedure. Args is the open payload; Stream is the
%% server-side macula_stream pid. The handler runs to completion (or
%% abort) in its own process — no need to be reentrant.
-spec handle(pid(), term()) -> ok.
handle(Stream, Args) ->
    case parse_args(Args) of
        {ok, Model, Messages, Opts} ->
            invoke_provider(Stream, Model, Messages, Opts);
        {error, missing_field} ->
            macula:abort(Stream, <<"bad_request">>,
                         <<"missing model or messages">>),
            ok
    end.

invoke_provider(Stream, Model, Messages, Opts) ->
    case chat_to_llm:chat_stream(Model, Messages, Opts) of
        {ok, Ref} ->
            bridge_loop(Stream, Ref);
        {error, Reason} ->
            macula:abort(Stream, <<"provider_error">>, format(Reason)),
            ok
    end.

bridge_loop(Stream, Ref) ->
    receive
        {llm_chunk, Ref, ChunkMap} ->
            handle_send(macula:send(Stream, ChunkMap, msgpack), Stream, Ref);
        {llm_done, Ref} ->
            macula:close(Stream),
            ok;
        {llm_error, Ref, Reason} ->
            macula:abort(Stream, <<"llm_error">>, format(Reason)),
            ok
    after ?IDLE_TIMEOUT_MS ->
        macula:abort(Stream, <<"timeout">>,
                     <<"no provider chunk in 5 minutes">>),
        ok
    end.

handle_send(ok, Stream, Ref) ->
    bridge_loop(Stream, Ref);
handle_send({error, _Reason}, _Stream, _Ref) ->
    %% Caller closed the stream; stop forwarding (provider keeps
    %% running until the next chunk is dropped, which we tolerate —
    %% Phase 3 will add explicit cancellation downstream into the
    %% provider connection).
    ok.

%%====================================================================
%% Internal
%%====================================================================

parse_args(#{<<"model">> := Model, <<"messages">> := Messages} = M) ->
    {ok, Model, Messages, maps:get(<<"opts">>, M, #{})};
parse_args(#{model := Model, messages := Messages} = M) ->
    {ok, Model, Messages, maps:get(opts, M, #{})};
parse_args(_) ->
    {error, missing_field}.

format(R) when is_binary(R) -> R;
format(R) when is_atom(R) -> atom_to_binary(R, utf8);
format(R) -> iolist_to_binary(io_lib:format("~p", [R])).
