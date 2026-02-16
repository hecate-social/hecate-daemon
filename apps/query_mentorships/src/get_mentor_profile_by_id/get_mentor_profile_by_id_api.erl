-module(get_mentor_profile_by_id_api).
-export([init/2, routes/0]).

routes() -> [{"/api/mentors/profiles/:agent_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    AgentId = cowboy_req:binding(agent_id, Req0),
    case get_mentor_profile_by_id:execute(AgentId) of
        {ok, Profile} ->
            hecate_api_utils:json_ok(#{profile => Profile}, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
