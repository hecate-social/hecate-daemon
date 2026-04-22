%%% @doc Emitter: realm_membership_resigned_v1 → mesh FACT on
%%% `{realm}.membership.resigned`.
%%%
%%% The realm server subscribes to this topic via
%%% `record_realm_membership_resigned` and the debounced rotation PM
%%% (`on_realm_membership_resigned_rotate_key`) triggers K_realm
%%% rotation after a 60s debounce window.
%%% @end
-module(realm_membership_resigned_v1_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"realm_membership_resigned_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(<<"realm_membership_resigned_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    publish(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%% --- Internal ---

publish(Data) ->
    case gf(membership_id, Data) of
        undefined ->
            logger:warning("[realm_membership_resigned_v1_to_mesh] missing membership_id");
        MId ->
            do_publish(MId, Data)
    end.

do_publish(MId, Data) ->
    case erlang:whereis(hecate_mesh_client) of
        undefined ->
            logger:info("[realm_membership_resigned_v1_to_mesh] mesh down; drop resign ~s",
                        [MId]);
        _Pid ->
            Topic = hecate_topics:realm_fact(<<"membership">>, <<"resigned">>, 1),
            Fact = #{
                membership_id => MId,
                realm_id      => gf(realm_id,    Data),
                member_did    => gf(member_did,  Data),
                resigned_at   => gf(resigned_at, Data, erlang:system_time(millisecond))
            },
            case hecate_mesh:publish(Topic, Fact) of
                ok ->
                    logger:info("[realm_membership_resigned_v1_to_mesh] ~s -> ~s",
                                [MId, Topic]);
                {error, Reason} ->
                    logger:warning("[realm_membership_resigned_v1_to_mesh] publish failed ~s: ~p",
                                   [MId, Reason])
            end
    end.

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
