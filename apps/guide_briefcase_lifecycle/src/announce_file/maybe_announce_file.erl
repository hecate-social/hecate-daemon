%%% @doc Handler for announce_file command.
%%%
%%% Idempotent by construction — the aggregate rejects re-announcement
%%% with `already_present`, so re-delivery of a FACT collapses to a
%%% no-op dispatch.
%%% @end
-module(maybe_announce_file).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{file_id := _, realm := _, path := _} = Payload) ->
    handle(announce_file_v1:new(Payload));
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(announce_file_v1:announce_file_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    Map   = announce_file_v1:to_map(Command),
    Event = file_announced_v1:new(Map),
    {ok, [file_announced_v1:to_map(Event)]}.

-spec dispatch(announce_file_v1:announce_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId   = announce_file_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    CmdMap   = announce_file_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = announce_file_v1,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = CmdMap#{command_type => announce_file_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
