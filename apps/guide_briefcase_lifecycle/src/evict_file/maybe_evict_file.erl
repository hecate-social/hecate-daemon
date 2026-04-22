%%% @doc Handler for evict_file_v1.
%%%
%%% Deletes the `.enc` from the local cache store, returns
%%% `file_evicted_v1`. `briefcase_cache_store:delete/1` is idempotent
%%% (returns `ok` on `enoent`) — safe to retry.
%%% @end
-module(maybe_evict_file).

-export([handle_with_state/2, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").
-include("briefcase_state.hrl").

-spec handle_with_state(map(), #briefcase_state{}) ->
    {ok, [map()]} | {error, term()}.
handle_with_state(Payload, _State) ->
    FileId = maps:get(file_id, Payload),
    case briefcase_cache_store:delete(FileId) of
        ok ->
            {ok, Event} = file_evicted_v1:new(#{file_id => FileId}),
            {ok, [file_evicted_v1:to_map(Event)]};
        {error, _} = Err ->
            Err
    end.

-spec dispatch(evict_file_v1:evict_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId   = evict_file_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    Payload  = evict_file_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = evict_file_v1,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => evict_file_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
