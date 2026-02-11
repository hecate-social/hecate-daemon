-module(serve_llm_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/llm/models", get_available_llms_page_api, []},
        {"/api/llm/chat", chat_to_llm_api, []},
        {"/api/llm/health", check_llm_health_api, []},
        {"/api/llm/providers", get_providers_page_api, []},
        {"/api/llm/providers/add", add_provider_api, []},
        {"/api/llm/providers/reload", reload_providers_api, []},
        {"/api/llm/providers/:name/remove", remove_provider_api, []}
    ].
