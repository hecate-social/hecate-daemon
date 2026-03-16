%%% @doc Web search tool — queries SearXNG instance for internet search results.
%%%
%%% SearXNG endpoint is configured via SEARXNG_URL environment variable.
%%% Returns a list of search results with title, url, and snippet.
%%% @end
-module(web_search).

-export([search/1, search/2, tool_definition/0]).

-define(DEFAULT_URL, "http://localhost:8888").
-define(MAX_RESULTS, 5).

-spec tool_definition() -> map().
tool_definition() ->
    #{
        name => <<"web_search">>,
        description => <<"Search the internet for information about a topic. Returns titles, URLs, and snippets.">>,
        input_schema => #{
            type => <<"object">>,
            properties => #{
                query => #{type => <<"string">>, description => <<"Search query">>}
            },
            required => [<<"query">>]
        }
    }.

-spec search(binary()) -> {ok, [map()]} | {error, term()}.
search(Query) ->
    search(Query, #{}).

-spec search(binary(), map()) -> {ok, [map()]} | {error, term()}.
search(Query, Opts) ->
    BaseUrl = searxng_url(),
    MaxResults = maps:get(max_results, Opts, ?MAX_RESULTS),
    Url = BaseUrl ++ "/search?q=" ++ http_uri_encode(binary_to_list(Query))
        ++ "&format=json&engines=google,duckduckgo,brave&pageno=1",
    case hackney:get(list_to_binary(Url), [{<<"Accept">>, <<"application/json">>}], <<>>,
                     [with_body, {recv_timeout, 15000}]) of
        {ok, 200, _Headers, Body} ->
            parse_results(Body, MaxResults);
        {ok, StatusCode, _Headers, Body} ->
            {error, {http_error, StatusCode, Body}};
        {error, Reason} ->
            {error, {request_failed, Reason}}
    end.

%% Internal

searxng_url() ->
    case os:getenv("SEARXNG_URL") of
        false -> ?DEFAULT_URL;
        Url -> Url
    end.

parse_results(Body, MaxResults) ->
    try
        Decoded = json:decode(Body),
        Results = case Decoded of
            #{<<"results">> := R} when is_list(R) -> R;
            _ -> []
        end,
        Trimmed = lists:sublist(Results, MaxResults),
        Mapped = lists:map(fun(R) ->
            #{
                title => maps:get(<<"title">>, R, <<>>),
                url => maps:get(<<"url">>, R, <<>>),
                snippet => maps:get(<<"content">>, R, <<>>)
            }
        end, Trimmed),
        {ok, Mapped}
    catch
        _:Reason ->
            {error, {parse_error, Reason}}
    end.

http_uri_encode([]) -> [];
http_uri_encode([H | T]) ->
    case H of
        $  -> [$+ | http_uri_encode(T)];
        C when C >= $a, C =< $z -> [C | http_uri_encode(T)];
        C when C >= $A, C =< $Z -> [C | http_uri_encode(T)];
        C when C >= $0, C =< $9 -> [C | http_uri_encode(T)];
        C when C =:= $-; C =:= $_; C =:= $.; C =:= $~ -> [C | http_uri_encode(T)];
        C ->
            Hi = C bsr 4,
            Lo = C band 16#0F,
            [$%, hex_digit(Hi), hex_digit(Lo) | http_uri_encode(T)]
    end.

hex_digit(N) when N < 10 -> $0 + N;
hex_digit(N) -> $A + N - 10.
