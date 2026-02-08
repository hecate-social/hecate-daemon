%%% @doc record_finding_v1 command
%%% Records a finding during the discovery phase.
-module(record_finding_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_finding_id/1, get_category/1,
         get_title/1, get_content/1, get_priority/1]).

-record(record_finding_v1, {
    cartwheel_id :: binary(),
    finding_id :: binary(),
    category   :: binary(),
    title      :: binary(),
    content    :: binary() | undefined,
    priority   :: binary()
}).

-export_type([record_finding_v1/0]).
-opaque record_finding_v1() :: #record_finding_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, record_finding_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId, title := Title} = Params) ->
    Cmd = #record_finding_v1{
        cartwheel_id = CartwheelId,
        finding_id = maps:get(finding_id, Params, generate_id()),
        category = maps:get(category, Params, <<"requirement">>),
        title = Title,
        content = maps:get(content, Params, undefined),
        priority = maps:get(priority, Params, <<"should">>)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(record_finding_v1()) -> {ok, record_finding_v1()} | {error, term()}.
validate(#record_finding_v1{title = T}) when
    not is_binary(T); byte_size(T) =:= 0 ->
    {error, invalid_title};
validate(#record_finding_v1{category = Cat}) when
    Cat =/= <<"requirement">>, Cat =/= <<"constraint">>,
    Cat =/= <<"risk">>, Cat =/= <<"domain_concept">>,
    Cat =/= <<"prior_art">> ->
    {error, invalid_category};
validate(#record_finding_v1{priority = Pri}) when
    Pri =/= <<"must">>, Pri =/= <<"should">>,
    Pri =/= <<"could">>, Pri =/= <<"wont">> ->
    {error, invalid_priority};
validate(#record_finding_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(record_finding_v1()) -> map().
to_map(#record_finding_v1{} = Cmd) ->
    #{
        command_type => <<"record_finding">>,
        cartwheel_id => Cmd#record_finding_v1.cartwheel_id,
        finding_id => Cmd#record_finding_v1.finding_id,
        category => Cmd#record_finding_v1.category,
        title => Cmd#record_finding_v1.title,
        content => Cmd#record_finding_v1.content,
        priority => Cmd#record_finding_v1.priority
    }.

-spec from_map(map()) -> {ok, record_finding_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#record_finding_v1{cartwheel_id = V}) -> V.
get_finding_id(#record_finding_v1{finding_id = V}) -> V.
get_category(#record_finding_v1{category = V}) -> V.
get_title(#record_finding_v1{title = V}) -> V.
get_content(#record_finding_v1{content = V}) -> V.
get_priority(#record_finding_v1{priority = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"fnd-", Ts/binary, "-", Rand/binary>>.
