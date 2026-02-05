%%% @doc submit_learning_v1 command
%%% Submits a new learning to the mentor agents domain.
-module(submit_learning_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_learning_id/1, get_submitter_id/1, get_category/1, get_domain/1,
         get_tags/1, get_title/1, get_description/1, get_bad_example/1,
         get_good_example/1, get_context/1, get_severity/1, get_confidence/1,
         get_source/1]).

-record(submit_learning_v1, {
    learning_id  :: binary(),
    submitter_id :: binary(),
    category     :: binary(),
    domain       :: binary(),
    tags         :: [binary()],
    title        :: binary(),
    description  :: binary() | undefined,
    bad_example  :: binary() | undefined,
    good_example :: binary() | undefined,
    context      :: binary() | undefined,
    severity     :: binary(),
    confidence   :: float(),
    source       :: binary()
}).

-export_type([submit_learning_v1/0]).
-opaque submit_learning_v1() :: #submit_learning_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, submit_learning_v1()} | {error, term()}.
new(#{category := Cat, domain := Dom, title := Title} = Params) ->
    LearningId = maps:get(learning_id, Params, generate_id()),
    SubmitterId = maps:get(submitter_id, Params, hecate_identity:agent_id()),
    Cmd = #submit_learning_v1{
        learning_id = LearningId,
        submitter_id = SubmitterId,
        category = Cat,
        domain = Dom,
        tags = maps:get(tags, Params, []),
        title = Title,
        description = maps:get(description, Params, undefined),
        bad_example = maps:get(bad_example, Params, undefined),
        good_example = maps:get(good_example, Params, undefined),
        context = maps:get(context, Params, undefined),
        severity = maps:get(severity, Params, <<"suggestion">>),
        confidence = maps:get(confidence, Params, 0.5),
        source = maps:get(source, Params, <<"discovered">>)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(submit_learning_v1()) -> {ok, submit_learning_v1()} | {error, term()}.
validate(#submit_learning_v1{category = Cat}) when
    Cat =/= <<"pattern">>, Cat =/= <<"antipattern">>,
    Cat =/= <<"example">>, Cat =/= <<"correction">> ->
    {error, invalid_category};
validate(#submit_learning_v1{severity = Sev}) when
    Sev =/= <<"critical">>, Sev =/= <<"important">>, Sev =/= <<"suggestion">> ->
    {error, invalid_severity};
validate(#submit_learning_v1{source = Src}) when
    Src =/= <<"discovered">>, Src =/= <<"taught">>, Src =/= <<"observed">> ->
    {error, invalid_source};
validate(#submit_learning_v1{confidence = C}) when C < 0.0; C > 1.0 ->
    {error, invalid_confidence};
validate(#submit_learning_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(submit_learning_v1()) -> map().
to_map(#submit_learning_v1{} = Cmd) ->
    #{
        command_type => <<"submit_learning">>,
        learning_id => Cmd#submit_learning_v1.learning_id,
        submitter_id => Cmd#submit_learning_v1.submitter_id,
        category => Cmd#submit_learning_v1.category,
        domain => Cmd#submit_learning_v1.domain,
        tags => Cmd#submit_learning_v1.tags,
        title => Cmd#submit_learning_v1.title,
        description => Cmd#submit_learning_v1.description,
        bad_example => Cmd#submit_learning_v1.bad_example,
        good_example => Cmd#submit_learning_v1.good_example,
        context => Cmd#submit_learning_v1.context,
        severity => Cmd#submit_learning_v1.severity,
        confidence => Cmd#submit_learning_v1.confidence,
        source => Cmd#submit_learning_v1.source
    }.

-spec from_map(map()) -> {ok, submit_learning_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_learning_id(#submit_learning_v1{learning_id = V}) -> V.
get_submitter_id(#submit_learning_v1{submitter_id = V}) -> V.
get_category(#submit_learning_v1{category = V}) -> V.
get_domain(#submit_learning_v1{domain = V}) -> V.
get_tags(#submit_learning_v1{tags = V}) -> V.
get_title(#submit_learning_v1{title = V}) -> V.
get_description(#submit_learning_v1{description = V}) -> V.
get_bad_example(#submit_learning_v1{bad_example = V}) -> V.
get_good_example(#submit_learning_v1{good_example = V}) -> V.
get_context(#submit_learning_v1{context = V}) -> V.
get_severity(#submit_learning_v1{severity = V}) -> V.
get_confidence(#submit_learning_v1{confidence = V}) -> V.
get_source(#submit_learning_v1{source = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"lrn-", Ts/binary, "-", Rand/binary>>.
