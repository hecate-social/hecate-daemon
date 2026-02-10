%%% @doc setup_venture_v1 command
%%% Sets up a new venture (business endeavor).
-module(setup_venture_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_name/1, get_brief/1, get_initiated_by/1]).
-export([generate_id/0]).

-record(setup_venture_v1, {
    venture_id   :: binary(),
    name         :: binary(),
    brief        :: binary() | undefined,
    initiated_by :: binary() | undefined
}).

-export_type([setup_venture_v1/0]).
-opaque setup_venture_v1() :: #setup_venture_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, setup_venture_v1()} | {error, term()}.
new(#{name := Name} = Params) ->
    VentureId = maps:get(venture_id, Params, generate_id()),
    {ok, #setup_venture_v1{
        venture_id = VentureId,
        name = Name,
        brief = maps:get(brief, Params, undefined),
        initiated_by = maps:get(initiated_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(setup_venture_v1()) -> {ok, setup_venture_v1()} | {error, term()}.
validate(#setup_venture_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#setup_venture_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(setup_venture_v1()) -> map().
to_map(#setup_venture_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"setup_venture">>,
        <<"venture_id">> => Cmd#setup_venture_v1.venture_id,
        <<"name">> => Cmd#setup_venture_v1.name,
        <<"brief">> => Cmd#setup_venture_v1.brief,
        <<"initiated_by">> => Cmd#setup_venture_v1.initiated_by
    }.

-spec from_map(map()) -> {ok, setup_venture_v1()} | {error, term()}.
from_map(Map) ->
    Name = get_value(name, Map),
    VentureId = get_value(venture_id, Map, generate_id()),
    Brief = get_value(brief, Map, undefined),
    InitiatedBy = get_value(initiated_by, Map, undefined),
    case Name of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #setup_venture_v1{
                venture_id = VentureId,
                name = Name,
                brief = Brief,
                initiated_by = InitiatedBy
            }}
    end.

%% Accessors
-spec get_venture_id(setup_venture_v1()) -> binary().
get_venture_id(#setup_venture_v1{venture_id = V}) -> V.

-spec get_name(setup_venture_v1()) -> binary().
get_name(#setup_venture_v1{name = V}) -> V.

-spec get_brief(setup_venture_v1()) -> binary() | undefined.
get_brief(#setup_venture_v1{brief = V}) -> V.

-spec get_initiated_by(setup_venture_v1()) -> binary() | undefined.
get_initiated_by(#setup_venture_v1{initiated_by = V}) -> V.

%% @doc Generate a unique venture ID
-spec generate_id() -> binary().
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"venture-", Ts/binary, "-", Rand/binary>>.

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
