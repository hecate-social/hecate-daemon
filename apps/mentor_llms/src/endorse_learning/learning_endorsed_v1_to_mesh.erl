%%% @doc Mesh emitter: learning_endorsed_v1 -> hecate.learning.endorsed
%%% Registered via evoq_event_handler; evoq_store_subscription routes events automatically.
-module(learning_endorsed_v1_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

-define(MESH_TOPIC, <<"hecate.learning.endorsed">>).

interested_in() -> [<<"learning_endorsed_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    hecate_mesh_client:publish(?MESH_TOPIC, Event),
    {ok, State}.
