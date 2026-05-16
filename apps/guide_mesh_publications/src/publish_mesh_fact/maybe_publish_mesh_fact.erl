%%% @doc Handler for publish_mesh_fact_v1 command.
%%%
%%% Validates the command shape and produces the matching domain event
%%% (`mesh_fact_published_v1'). The actual mesh publish happens in the
%%% emitter that reacts to this event, NOT here — that's the doctrinal
%%% boundary between an internal EVENT and an external FACT.
%%% @end
-module(maybe_publish_mesh_fact).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{topic := Topic, fact := Fact} = Payload)
  when is_binary(Topic), is_map(Fact) ->
    RequestedAt = maps:get(requested_at, Payload, erlang:system_time(millisecond)),
    Cmd = publish_mesh_fact_v1:new(Topic, Fact, RequestedAt),
    handle(Cmd);
handle_from_map(_) ->
    {error, missing_topic_or_fact}.

-spec handle(publish_mesh_fact_v1:publish_mesh_fact_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{topic := Topic, fact := Fact, requested_at := RequestedAt}
        = publish_mesh_fact_v1:to_map(Command),
    Event = mesh_fact_published_v1:new(Topic, Fact, RequestedAt),
    {ok, [mesh_fact_published_v1:to_map(Event)]}.

-spec dispatch(publish_mesh_fact_v1:publish_mesh_fact_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CmdMap = publish_mesh_fact_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = publish_mesh_fact_v1,
        aggregate_type = mesh_publications_aggregate,
        aggregate_id = mesh_publications_aggregate:stream_id(),
        payload = CmdMap#{command_type => publish_mesh_fact_v1},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mesh_publications_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
