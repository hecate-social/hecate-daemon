-module(get_briefcase_folders_api).
-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/folders", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            {ok, Folders} = project_briefcase_store:list_folders(),
            hecate_api_utils:json_ok(#{folders => Folders}, Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.
