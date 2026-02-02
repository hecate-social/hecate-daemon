%%%-------------------------------------------------------------------
%%% @doc UCAN capability wallet.
%%%
%%% Manages capability tokens for authorization.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_ucan).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([
    grant/3,
    revoke/1,
    list/0,
    verify/1
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(BUCKET, <<"ucan">>).

-record(state, {
    capabilities :: map()
}).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec grant(To :: binary(), Can :: binary(), Resource :: binary()) -> {ok, binary()}.
grant(To, Can, Resource) ->
    gen_server:call(?SERVER, {grant, To, Can, Resource}).

-spec revoke(Id :: binary()) -> ok | {error, not_found}.
revoke(Id) ->
    gen_server:call(?SERVER, {revoke, Id}).

-spec list() -> [map()].
list() ->
    gen_server:call(?SERVER, list).

-spec verify(Token :: binary()) -> {ok, map()} | {error, term()}.
verify(Token) ->
    gen_server:call(?SERVER, {verify, Token}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    Caps = maps:from_list(hecate_store:list(?BUCKET)),
    {ok, #state{capabilities = Caps}}.

handle_call({grant, To, Can, Resource}, _From, #state{capabilities = Caps} = State) ->
    Id = generate_id(),
    
    %% Build UCAN structure
    {ok, Issuer} = hecate_identity:get_mri(),
    Cap = #{
        id => Id,
        iss => Issuer,
        aud => To,
        att => [#{
            with => Resource,
            can => Can
        }],
        exp => erlang:system_time(second) + (7 * 24 * 3600), %% 7 days
        granted_at => erlang:system_time(second)
    },
    
    %% Sign it
    CapBin = json:encode(Cap),
    {ok, Signature} = hecate_identity:sign(CapBin),
    SignedCap = Cap#{signature => base64:encode(Signature)},
    
    ok = hecate_store:put(?BUCKET, Id, SignedCap),
    ok = hecate_store:append_event(<<"ucan">>, <<"capability_granted">>, SignedCap),
    
    logger:info("Granted capability ~s to ~s: ~s on ~s", [Id, To, Can, Resource]),
    
    {reply, {ok, Id}, State#state{capabilities = maps:put(Id, SignedCap, Caps)}};

handle_call({revoke, Id}, _From, #state{capabilities = Caps} = State) ->
    case maps:is_key(Id, Caps) of
        true ->
            ok = hecate_store:delete(?BUCKET, Id),
            ok = hecate_store:append_event(<<"ucan">>, <<"capability_revoked">>, #{id => Id}),
            logger:info("Revoked capability: ~s", [Id]),
            {reply, ok, State#state{capabilities = maps:remove(Id, Caps)}};
        false ->
            {reply, {error, not_found}, State}
    end;

handle_call(list, _From, #state{capabilities = Caps} = State) ->
    {reply, maps:values(Caps), State};

handle_call({verify, _Token}, _From, State) ->
    %% TODO: Implement UCAN verification
    {reply, {error, not_implemented}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

generate_id() ->
    base64:encode(crypto:strong_rand_bytes(12)).
