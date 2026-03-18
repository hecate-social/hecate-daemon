%%% @doc Process Manager: On document renamed (Scribe), sync file name in Briefcase.
%%%
%%% Subscribes to document_renamed_v1 events from the Scribe plugin's
%%% documents_store. Dispatches rename_file to briefcase_store so the
%%% file listing stays in sync with the document's authoritative name.
%%%
%%% The documents_store is a plugin store — it only exists when Scribe
%%% is installed. This PM gracefully retries subscription if the store
%%% is not yet available.
%%% @end
-module(on_document_renamed_sync_file).
-behaviour(evoq_event_handler).

-include_lib("evoq/include/evoq.hrl").

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"document_renamed_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    do_handle(Data),
    {ok, State}.

do_handle(Data) ->
    DocId = get_value(document_id, Data),
    NewTitle = get_value(new_title, Data),
    case {DocId, NewTitle} of
        {undefined, _} -> ok;
        {_, undefined} -> ok;
        _ ->
            dispatch_rename(DocId, NewTitle)
    end.

dispatch_rename(FileId, Name) ->
    Cmd = #evoq_command{
        command_type = rename_file,
        aggregate_type = file_aggregate,
        aggregate_id = FileId,
        payload = #{
            command_type => <<"rename_file">>,
            file_id => FileId,
            name => Name
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    Opts = #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    case evoq_dispatcher:dispatch(Cmd, Opts) of
        {ok, _, _} ->
            logger:info("[PM] Synced file name ~s -> ~s", [FileId, Name]);
        {error, file_not_initiated} ->
            %% File not yet registered in Briefcase — ignore
            logger:debug("[PM] File ~s not in Briefcase, skipping rename sync", [FileId]);
        {error, Reason} ->
            logger:warning("[PM] Failed to sync file name ~s: ~p", [FileId, Reason])
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
