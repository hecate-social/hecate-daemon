%%% @doc Check LLM Health
%%% Checks if Ollama backend is healthy.
-module(check_llm_health).

-export([check/0]).

-define(OLLAMA_URL, "http://localhost:11434").

-spec check() -> ok | {error, term()}.
check() ->
    BaseUrl = get_ollama_url(),
    Url = BaseUrl ++ "/api/tags",
    case hackney:get(Url, [], <<>>, [with_body, {recv_timeout, 5000}]) of
        {ok, 200, _Headers, _Body} ->
            ok;
        {ok, Status, _Headers, _Body} ->
            {error, {http_status, Status}};
        {error, Reason} ->
            {error, Reason}
    end.

get_ollama_url() ->
    case os:getenv("OLLAMA_HOST") of
        false -> application:get_env(serve_llm, ollama_url, ?OLLAMA_URL);
        Url -> Url
    end.
