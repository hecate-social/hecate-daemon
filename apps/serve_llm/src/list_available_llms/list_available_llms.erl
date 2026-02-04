%%% @doc List Available LLMs
%%% Lists models available from Ollama.
-module(list_available_llms).

-export([list/0]).

-define(OLLAMA_URL, "http://localhost:11434").

-spec list() -> {ok, list()} | {error, term()}.
list() ->
    BaseUrl = get_ollama_url(),
    Url = BaseUrl ++ "/api/tags",
    case hackney:get(Url, [], <<>>, [with_body]) of
        {ok, 200, _Headers, Body} ->
            #{<<"models">> := Models} = json:decode(Body),
            {ok, Models};
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
