%%% @doc learning_submitted_v1 event
%%% Emitted when a learning is successfully submitted.
-module(learning_submitted_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_learning_id/1, get_submitter_id/1, get_category/1, get_domain/1,
         get_tags/1, get_title/1, get_description/1, get_bad_example/1,
         get_good_example/1, get_context/1, get_severity/1, get_confidence/1,
         get_source/1, get_submitted_at/1]).

-record(learning_submitted_v1, {
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
    source       :: binary(),
    submitted_at :: integer()
}).

-export_type([learning_submitted_v1/0]).
-opaque learning_submitted_v1() :: #learning_submitted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> learning_submitted_v1().
new(#{learning_id := LId, submitter_id := SId, category := Cat,
      domain := Dom, title := Title} = Params) ->
    #learning_submitted_v1{
        learning_id = LId,
        submitter_id = SId,
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
        source = maps:get(source, Params, <<"discovered">>),
        submitted_at = erlang:system_time(millisecond)
    }.

-spec to_map(learning_submitted_v1()) -> map().
to_map(#learning_submitted_v1{} = E) ->
    #{
        event_type => <<"learning_submitted_v1">>,
        learning_id => E#learning_submitted_v1.learning_id,
        submitter_id => E#learning_submitted_v1.submitter_id,
        category => E#learning_submitted_v1.category,
        domain => E#learning_submitted_v1.domain,
        tags => E#learning_submitted_v1.tags,
        title => E#learning_submitted_v1.title,
        description => E#learning_submitted_v1.description,
        bad_example => E#learning_submitted_v1.bad_example,
        good_example => E#learning_submitted_v1.good_example,
        context => E#learning_submitted_v1.context,
        severity => E#learning_submitted_v1.severity,
        confidence => E#learning_submitted_v1.confidence,
        source => E#learning_submitted_v1.source,
        submitted_at => E#learning_submitted_v1.submitted_at
    }.

-spec from_map(map()) -> {ok, learning_submitted_v1()} | {error, term()}.
from_map(#{learning_id := LId, submitter_id := SId, category := Cat,
           domain := Dom, title := Title} = Map) ->
    {ok, #learning_submitted_v1{
        learning_id = LId,
        submitter_id = SId,
        category = Cat,
        domain = Dom,
        tags = maps:get(tags, Map, []),
        title = Title,
        description = maps:get(description, Map, undefined),
        bad_example = maps:get(bad_example, Map, undefined),
        good_example = maps:get(good_example, Map, undefined),
        context = maps:get(context, Map, undefined),
        severity = maps:get(severity, Map, <<"suggestion">>),
        confidence = maps:get(confidence, Map, 0.5),
        source = maps:get(source, Map, <<"discovered">>),
        submitted_at = maps:get(submitted_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_learning_id(#learning_submitted_v1{learning_id = V}) -> V.
get_submitter_id(#learning_submitted_v1{submitter_id = V}) -> V.
get_category(#learning_submitted_v1{category = V}) -> V.
get_domain(#learning_submitted_v1{domain = V}) -> V.
get_tags(#learning_submitted_v1{tags = V}) -> V.
get_title(#learning_submitted_v1{title = V}) -> V.
get_description(#learning_submitted_v1{description = V}) -> V.
get_bad_example(#learning_submitted_v1{bad_example = V}) -> V.
get_good_example(#learning_submitted_v1{good_example = V}) -> V.
get_context(#learning_submitted_v1{context = V}) -> V.
get_severity(#learning_submitted_v1{severity = V}) -> V.
get_confidence(#learning_submitted_v1{confidence = V}) -> V.
get_source(#learning_submitted_v1{source = V}) -> V.
get_submitted_at(#learning_submitted_v1{submitted_at = V}) -> V.
