%%% @doc API handler: POST /api/llm/providers/:name/remove
%%%
%%% Remove an LLM provider by name.
%%% Returns error if trying to remove the default Ollama provider.
%%% @end
-module(remove_provider_api).

-export([init/2, routes/0]).

routes() -> [{"/api/llm/providers/:name/remove", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    Name = cowboy_req:binding(name, Req0),
    case manage_providers:remove(Name) of
        ok ->
            manage_providers:refresh_models(),
            hecate_api_utils:json_ok(#{}, Req0);
        {error, cannot_remove_default} ->
            hecate_api_utils:bad_request(<<"Cannot remove default Ollama provider">>, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0)
    end.
