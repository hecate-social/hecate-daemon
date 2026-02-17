%%% @doc Handler: Load champion network and spawn a duel process.
%%%
%%% Loads the champion from the query store, deserializes the network,
%%% and starts a gladiator_duel_proc via the dynamic supervisor.
%%%
%%% Handles topology migration: old champions (22 or 27 inputs)
%%% are zero-padded to the current topology (31 inputs, 5 outputs).
%%% Zero-padded new inputs default to 0.0 — safe neutral value.
%%% @end
-module(maybe_start_champion_duel).

-include("gladiator.hrl").

-export([handle/1, maybe_migrate_topology/1]).

-spec handle(term()) -> {ok, binary()} | {error, term()}.
handle(Cmd) ->
    StableId = start_champion_duel_v1:stable_id(Cmd),
    OppAF = start_champion_duel_v1:opponent_af(Cmd),
    TickMs = start_champion_duel_v1:tick_ms(Cmd),
    Rank = start_champion_duel_v1:rank(Cmd),

    case query_snake_gladiators_store:get_champion(StableId, Rank) of
        {ok, #{network_json := NetworkJson}} ->
            %% Deserialize champion network (with topology migration if needed)
            NetworkData0 = json:decode(NetworkJson),
            NetworkData = maybe_migrate_topology(NetworkData0),
            {ok, Network} = network_evaluator:from_json(NetworkData),

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

%% Detect old topology and zero-pad weight matrices at JSON level.
%% Old champions with topology {22, [24, 12], 4} are migrated to
%% {26, [28, 14], 5} by zero-padding weight matrices.
%%
%% Migration strategy per layer:
%%   Layer 1 (input→hidden1): 24x22 → 28x26
%%     - Existing 24 rows: each gets 4 zero columns (new inputs)
%%     - Add 4 new rows of 26 zeros + zero biases (new hidden neurons)
%%   Layer 2 (hidden1→hidden2): 12x24 → 14x28
%%     - Existing 12 rows: each gets 4 zero columns (connections from new h1 neurons)
%%     - Add 2 new rows of 28 zeros + zero biases (new hidden neurons)
%%   Layer 3 (hidden2→output): 4x12 → 5x14
%%     - Existing 4 rows: each gets 2 zero columns (connections from new h2 neurons)
%%     - Add 1 new row of 14 zeros + zero bias (drop-tail output ≈ 0 → never drops)
maybe_migrate_topology(#{<<"layers">> := Layers} = NetworkData) ->
    [#{<<"weights">> := W1} | _] = Layers,
    FirstRowLen = length(hd(W1)),
    case FirstRowLen of
        ?GLADIATOR_INPUTS ->
            NetworkData;
        ?GLADIATOR_INPUTS_V2 ->
            %% 27-input champion: zero-pad 4 new sensor inputs, keep hidden/output same
            logger:info("[gladiator_duel] Migrating champion from v2 topology "
                        "(~p inputs) to v3 (~p inputs)",
                        [?GLADIATOR_INPUTS_V2, ?GLADIATOR_INPUTS]),
            migrate_input_pad(NetworkData, ?GLADIATOR_INPUTS - ?GLADIATOR_INPUTS_V2);
        ?GLADIATOR_INPUTS_V1 ->
            logger:info("[gladiator_duel] Migrating champion from v1 topology "
                        "(~p inputs) to current (~p inputs)",
                        [?GLADIATOR_INPUTS_V1, ?GLADIATOR_INPUTS]),
            migrate_layers(NetworkData);
        Other ->
            logger:warning("[gladiator_duel] Unknown topology input count: ~p, "
                           "proceeding without migration", [Other]),
            NetworkData
    end.

%% Pad only the first layer with extra zero columns for new inputs.
%% Hidden layers and output layer keep their topology unchanged.
%% Works for any N extra inputs (e.g., v2→v3 adds 4 flood-fill sensors).
migrate_input_pad(#{<<"layers">> := [L1 | Rest]} = NetworkData, ExtraCols) ->
    #{<<"weights">> := W1} = L1,
    W1Padded = [Row ++ lists:duplicate(ExtraCols, 0.0) || Row <- W1],
    L1Padded = L1#{<<"weights">> := W1Padded},
    NetworkData#{<<"layers">> := [L1Padded | Rest]};
migrate_input_pad(NetworkData, _ExtraCols) ->
    NetworkData.

migrate_layers(#{<<"layers">> := [L1, L2, L3]} = NetworkData) ->
    #{<<"weights">> := W1, <<"biases">> := B1} = L1,
    #{<<"weights">> := W2, <<"biases">> := B2} = L2,
    #{<<"weights">> := W3, <<"biases">> := B3} = L3,

    %% Layer 1: 24x22 → 28x26 (4 new input cols, 4 new neuron rows)
    NewInputCols = ?GLADIATOR_INPUTS - ?GLADIATOR_INPUTS_V1,  %% 4
    NewH1Neurons = 28 - 24,  %% 4
    W1a = [Row ++ lists:duplicate(NewInputCols, 0.0) || Row <- W1],
    ZeroRow1 = lists:duplicate(?GLADIATOR_INPUTS, 0.0),
    W1b = W1a ++ lists:duplicate(NewH1Neurons, ZeroRow1),
    B1b = B1 ++ lists:duplicate(NewH1Neurons, 0.0),

    %% Layer 2: 12x24 → 14x28 (4 new input cols from h1, 2 new neuron rows)
    NewH1Cols = 28 - 24,  %% 4
    NewH2Neurons = 14 - 12,  %% 2
    W2a = [Row ++ lists:duplicate(NewH1Cols, 0.0) || Row <- W2],
    ZeroRow2 = lists:duplicate(28, 0.0),
    W2b = W2a ++ lists:duplicate(NewH2Neurons, ZeroRow2),
    B2b = B2 ++ lists:duplicate(NewH2Neurons, 0.0),

    %% Layer 3: 4x12 → 5x14 (2 new input cols from h2, 1 new output row)
    NewH2Cols = 14 - 12,  %% 2
    NewOutputs = ?GLADIATOR_OUTPUTS - ?GLADIATOR_OUTPUTS_V1,  %% 1
    W3a = [Row ++ lists:duplicate(NewH2Cols, 0.0) || Row <- W3],
    ZeroRow3 = lists:duplicate(14, 0.0),
    W3b = W3a ++ lists:duplicate(NewOutputs, ZeroRow3),
    B3b = B3 ++ lists:duplicate(NewOutputs, 0.0),

    NetworkData#{<<"layers">> := [
        #{<<"weights">> => W1b, <<"biases">> => B1b},
        #{<<"weights">> => W2b, <<"biases">> => B2b},
        #{<<"weights">> => W3b, <<"biases">> => B3b}
    ]}.

generate_match_id() ->
    Bytes = crypto:strong_rand_bytes(6),
    Hex = binary:encode_hex(Bytes, lowercase),
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    <<"gduel-", Ts/binary, "-", Hex/binary>>.
