%%% @doc API handler: GET /api/briefcase/files
%%%
%%% Returns all known files in the briefcase read model. Later phases
%%% add pagination, realm/path filtering, sort options.
%%% @end
-module(get_files_page_api).

-export([init/2, routes/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

routes() -> [{"/api/briefcase/files", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case list_active() of
        {ok, Files} ->
            hecate_api_utils:json_ok(#{items => Files}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

%% Phase 1: read directly from the briefcase_files ETS table.
%% Phase 2+: add a dedicated store module (project_briefcase_files_store).
list_active() ->
    try
        Entries = [V || {_K, V} <- ets:tab2list(briefcase_files)],
        {ok, Entries}
    catch
        error:badarg -> {ok, []}
    end.
