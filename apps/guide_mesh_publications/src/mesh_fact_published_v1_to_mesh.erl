%%% @doc Emitter: mesh_fact_published_v1 -> Macula mesh.
%%%
%%% Subscribes via evoq_event_handler to the `mesh_fact_published_v1'
%%% domain event and pushes the carried fact onto the agent-chosen
%%% mesh topic via `hecate_mesh:publish/2'. This is the doctrinal
%%% DOMAIN_EVENT -> EMITTER -> FACT transition: the FACT shape on the
%%% wire is exactly the agent-supplied payload; this daemon adds no
%%% wrapping in v1 (provenance is implicit in macula's signing layer).
%%% @end
-module(mesh_fact_published_v1_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"mesh_fact_published_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, #{topic := Topic, fact := Fact}, _Metadata, State)
  when is_binary(Topic), is_map(Fact) ->
    case hecate_mesh:publish(Topic, Fact) of
        ok ->
            {ok, State};
        {error, Reason} ->
            logger:warning("[mesh_fact_published_v1_to_mesh] publish to ~s failed: ~p",
                           [Topic, Reason]),
            {ok, State}
    end;
handle_event(_EventType, Data, _Metadata, State) ->
    logger:warning("[mesh_fact_published_v1_to_mesh] dropping malformed event: ~p", [Data]),
    {ok, State}.
