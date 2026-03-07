%%% @doc Emitter: license_published_v1 -> mesh (external pub/sub)
%%% Registered via evoq_event_handler; evoq_store_subscription routes events automatically.
-module(license_published_v1_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

-define(MESH_TOPIC, <<"appstore.plugin_published">>).

interested_in() -> [<<"license_published_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    hecate_mesh:publish(?MESH_TOPIC, Event),
    {ok, State}.
