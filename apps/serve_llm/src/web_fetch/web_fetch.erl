%%% @doc Web fetch tool — fetches a URL and extracts text content.
%%%
%%% Uses hackney to GET the page and strips HTML tags to return plain text.
%%% Truncates to a reasonable size for LLM context windows.
%%% @end
-module(web_fetch).

-export([fetch/1, fetch/2, tool_definition/0]).

-define(MAX_BODY_SIZE, 100000).   %% 100KB max raw body
-define(MAX_TEXT_SIZE, 20000).    %% 20KB max extracted text

-spec tool_definition() -> map().
tool_definition() ->
    #{
        name => <<"web_fetch">>,
        description => <<"Fetch and extract text content from a URL. Returns the main text content of the page.">>,
        input_schema => #{
            type => <<"object">>,
            properties => #{
                url => #{type => <<"string">>, description => <<"URL to fetch">>}
            },
            required => [<<"url">>]
        }
    }.

-spec fetch(binary()) -> {ok, binary()} | {error, term()}.
fetch(Url) ->
    fetch(Url, #{}).

-spec fetch(binary(), map()) -> {ok, binary()} | {error, term()}.
fetch(Url, _Opts) ->
    Headers = [
        {<<"User-Agent">>, <<"Mozilla/5.0 (compatible; HecateBot/1.0)">>},
        {<<"Accept">>, <<"text/html,application/xhtml+xml,text/plain">>}
    ],
    case hackney:get(Url, Headers, <<>>,
                     [with_body, {recv_timeout, 15000}, {max_body, ?MAX_BODY_SIZE},
                      {follow_redirect, true}, {max_redirect, 3}]) of
        {ok, 200, _Headers, Body} ->
            Text = extract_text(Body),
            Truncated = truncate(Text, ?MAX_TEXT_SIZE),
            {ok, Truncated};
        {ok, StatusCode, _Headers, _Body} ->
            {error, {http_error, StatusCode}};
        {error, Reason} ->
            {error, {request_failed, Reason}}
    end.

%% Internal

extract_text(Html) ->
    %% Remove script and style blocks first
    NoScript = re_remove(Html, <<"<script[^>]*>.*?</script>">>),
    NoStyle = re_remove(NoScript, <<"<style[^>]*>.*?</style>">>),
    %% Remove all HTML tags
    NoTags = re:replace(NoStyle, <<"<[^>]+>">>, <<" ">>, [global, {return, binary}]),
    %% Decode common HTML entities
    Decoded = decode_entities(NoTags),
    %% Collapse whitespace
    Collapsed = re:replace(Decoded, <<"\\s+">>, <<" ">>, [global, {return, binary}]),
    string:trim(Collapsed).

re_remove(Text, Pattern) ->
    case re:replace(Text, Pattern, <<>>, [global, caseless, dotall, {return, binary}]) of
        Result when is_binary(Result) -> Result;
        _ -> Text
    end.

decode_entities(Text) ->
    T1 = binary:replace(Text, <<"&amp;">>, <<"&">>, [global]),
    T2 = binary:replace(T1, <<"&lt;">>, <<"<">>, [global]),
    T3 = binary:replace(T2, <<"&gt;">>, <<">">>, [global]),
    T4 = binary:replace(T3, <<"&quot;">>, <<"\"">>, [global]),
    binary:replace(T4, <<"&#39;">>, <<"'">>, [global]).

truncate(Text, MaxSize) when byte_size(Text) > MaxSize ->
    <<Prefix:MaxSize/binary, _/binary>> = Text,
    <<Prefix/binary, "...">>;
truncate(Text, _MaxSize) ->
    Text.
