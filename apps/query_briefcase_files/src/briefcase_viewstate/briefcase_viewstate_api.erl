%%% @doc API: GET /api/viewstate/briefcase/files
%%%
%%% Returns the array of UI-ready file rows. Each row carries:
%%%
%%%   - all the read-model fields (file_id, path, mime_type, size,
%%%     presence, status_label, ...)
%%%   - `guard`: the open-path guard outcome for remote/cached rows
%%%     (`{state, reason}` — state is ok | refused | not_applicable)
%%%   - `available_actions`: list of action descriptors the frontend
%%%     renders as buttons / progress bars
%%%
%%% Frontend responsibility shrinks to "render rows + map action
%%% descriptors to buttons that call the descriptor's URL". Business
%%% logic — what's open-able, when, with which guard refusal — lives
%%% in `briefcase_viewstate`, daemon-side.
%%% @end
-module(briefcase_viewstate_api).

-export([init/2, routes/0]).

routes() -> [{"/api/viewstate/briefcase/files", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    {ok, Rows} = briefcase_viewstate:list_files(),
    hecate_api_utils:json_ok(#{files => Rows}, Req0).
