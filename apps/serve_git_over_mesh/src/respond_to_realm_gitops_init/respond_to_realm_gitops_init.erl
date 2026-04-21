%%% @doc Desk worker: advertises the
%%% `{Realm}.config.gitops.initiate` HOPE so the realm server
%%% (macula-realm) can provision a gitops repo on the user's node.
%%%
%%% The actual handler logic lives in
%%% {@link handle_realm_gitops_init}; this module's only job is
%%% lifecycle: register the advertisement at boot (which the mesh
%%% client holds as pending until activation), refuse to double-
%%% register.
%%%
%%% Realm resolution:
%%%   - Uses `hecate_topics:realm/0` — the joined realm from
%%%     application env, defaulting to `<<"io.macula">>` when the
%%%     daemon has not yet joined. The advertisement is still
%%%     registered in that case; re-registering on realm change
%%%     would require a listener on the settings store, which is a
%%%     follow-up.
%%% @end
-module(respond_to_realm_gitops_init).
-behaviour(gen_server).

-export([start_link/0, advertised_procedure/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    procedure :: binary(),
    realm     :: binary()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Return the procedure URI this desk advertises.
%% Useful for eunit + operator diagnostics.
-spec advertised_procedure() -> binary().
advertised_procedure() ->
    procedure_uri(hecate_topics:realm()).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    Realm = hecate_topics:realm(),
    Procedure = procedure_uri(Realm),
    Handler = fun(Args) -> handle_realm_gitops_init:handle(Realm, Args) end,
    ok = hecate_mesh_client:register_advertisement(Procedure, Handler),
    logger:info("[respond_to_realm_gitops_init] Advertised ~s", [Procedure]),
    {ok, #state{procedure = Procedure, realm = Realm}}.

handle_call(_Request, _From, State) -> {reply, {error, unknown}, State}.
handle_cast(_Msg, State)            -> {noreply, State}.
handle_info(_Info, State)           -> {noreply, State}.

terminate(_Reason, #state{procedure = Procedure}) ->
    _ = hecate_mesh_client:unregister_advertisement(Procedure),
    ok.

%%====================================================================
%% Internal
%%====================================================================

-spec procedure_uri(binary()) -> binary().
procedure_uri(Realm) when is_binary(Realm) ->
    <<Realm/binary, ".config.gitops.initiate">>.
