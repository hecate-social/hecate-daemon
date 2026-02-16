%%% @doc Handler: Load champion network and spawn a duel process.
%%%
%%% Loads the champion from the query store, deserializes the network,
%%% and starts a gladiator_duel_proc via the dynamic supervisor.
%%% @end
-module(maybe_start_champion_duel).

-export([handle/1]).

-spec handle(term()) -> {ok, binary()} | {error, term()}.
handle(Cmd) ->
    StableId = start_champion_duel_v1:stable_id(Cmd),
    OppAF = start_champion_duel_v1:opponent_af(Cmd),
    TickMs = start_champion_duel_v1:tick_ms(Cmd),

    case query_snake_gladiators_store:get_champion(StableId) of
        {ok, #{network_json := NetworkJson}} ->
            %% Deserialize champion network
            NetworkData = json:decode(NetworkJson),
            Network = network_evaluator:from_json(NetworkData),

            %% Generate match ID
            MatchId = generate_match_id(),

            %% Start duel process
            Config = #{
                match_id => MatchId,
                network => Network,
                opponent_af => OppAF,
                tick_ms => TickMs
            },
            case gladiator_duel_proc_sup:start_duel(Config) of
                {ok, _Pid} ->
                    {ok, MatchId};
                {error, Reason} ->
                    {error, {duel_start_failed, Reason}}
            end;
        {error, not_found} ->
            {error, {champion_not_found, StableId}}
    end.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

generate_match_id() ->
    Bytes = crypto:strong_rand_bytes(6),
    Hex = binary:encode_hex(Bytes, lowercase),
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    <<"gduel-", Ts/binary, "-", Hex/binary>>.
