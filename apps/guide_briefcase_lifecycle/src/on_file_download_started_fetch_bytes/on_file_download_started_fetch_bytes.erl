%%% @doc Evoq event handler: `file_download_started_v1` ->
%%% `briefcase_download_worker` spawn.
%%%
%%% Same directory name → filesystem-level discoverability of "when
%%% a download starts, we fetch the bytes". The PM is how we
%%% decouple the cowboy worker (which emitted the event) from the
%%% long-running fetch (which runs under its own supervised gen_server).
%%% @end
-module(on_file_download_started_fetch_bytes).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"file_download_started_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(<<"file_download_started_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    FileId = gf(file_id, Data),
    Realm  = gf(realm, Data),
    case {FileId, Realm} of
        {undefined, _} ->
            logger:warning("[on_file_download_started] missing file_id in event"),
            {ok, State};
        {_, undefined} ->
            logger:warning("[on_file_download_started] missing realm in event"),
            {ok, State};
        _ ->
            case briefcase_download_sup:start_worker(FileId, Realm) of
                {ok, _Pid} ->
                    logger:info(
                        "[on_file_download_started] worker started file=~s realm=~s",
                        [FileId, Realm]);
                {error, {already_started, _}} ->
                    logger:debug(
                        "[on_file_download_started] worker already running file=~s",
                        [FileId]);
                {error, Reason} ->
                    logger:warning(
                        "[on_file_download_started] worker start failed file=~s: ~p",
                        [FileId, Reason])
            end,
            {ok, State}
    end;
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%% --- Internal ---

gf(K, M) ->
    case maps:find(K, M) of
        {ok, V} -> V;
        error ->
            case is_atom(K) of
                true  -> maps:get(atom_to_binary(K, utf8), M, undefined);
                false -> undefined
            end
    end.
