%%% @doc post_event_sticky_v1 command
%%% Posts a new event sticky during Big Picture Event Storming.
-module(post_event_sticky_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_text/1, get_author/1]).

-record(post_event_sticky_v1, {
    venture_id :: binary(),
    text       :: binary(),
    author     :: binary()
}).

-export_type([post_event_sticky_v1/0]).
-opaque post_event_sticky_v1() :: #post_event_sticky_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, post_event_sticky_v1()} | {error, term()}.
new(#{venture_id := VentureId, text := Text} = Params) ->
    Cmd = #post_event_sticky_v1{
        venture_id = VentureId,
        text = Text,
        author = maps:get(author, Params, <<"user">>)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(post_event_sticky_v1()) -> ok | {error, term()}.
validate(#post_event_sticky_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#post_event_sticky_v1{text = T}) when not is_binary(T); T =:= <<>> ->
    {error, {invalid_field, text}};
validate(_) -> ok.

-spec to_map(post_event_sticky_v1()) -> map().
to_map(#post_event_sticky_v1{venture_id = V, text = T, author = A}) ->
    #{
        <<"command_type">> => <<"post_event_sticky">>,
        <<"venture_id">> => V,
        <<"text">> => T,
        <<"author">> => A
    }.

-spec from_map(map()) -> {ok, post_event_sticky_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    Text = get_value(text, Map),
    Author = get_value(author, Map, <<"user">>),
    case {VentureId, Text} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, text => Text, author => Author})
    end.

-spec get_venture_id(post_event_sticky_v1()) -> binary().
get_venture_id(#post_event_sticky_v1{venture_id = V}) -> V.

-spec get_text(post_event_sticky_v1()) -> binary().
get_text(#post_event_sticky_v1{text = V}) -> V.

-spec get_author(post_event_sticky_v1()) -> binary().
get_author(#post_event_sticky_v1{author = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
