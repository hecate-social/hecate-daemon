%%% @doc Projection: entry_unregistered_v1 -> launcher ETS read model.
%%% Removes a launcher entry.
-module(entry_unregistered_v1_to_launcher).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

interested_in() -> [<<"entry_unregistered_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => launcher_entries}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    EntryId = gf(entry_id, Data),
    {ok, RM2} = evoq_read_model:delete(EntryId, RM),
    {ok, State, RM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
