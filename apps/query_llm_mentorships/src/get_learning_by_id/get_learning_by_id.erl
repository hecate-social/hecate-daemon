%%% @doc Query: find a learning by ID
-module(get_learning_by_id).

-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(LearningId) ->
    Sql = "SELECT id, submitter_id, category, domain, tags, title, "
          "description, bad_example, good_example, context, severity, "
          "confidence, source, status, validator_id, endorsement_count, "
          "dispute_count, submitted_at, validated_at "
          "FROM learnings WHERE id = ?1",
    case project_llm_mentorships_store:query(Sql, [LearningId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map([Id, SubmitterId, Category, Domain, TagsJson, Title,
            Desc, BadEx, GoodEx, Context, Severity, Confidence,
            Source, Status, ValidatorId, EndCount, DispCount,
            SubmittedAt, ValidatedAt]) ->
    Tags = case TagsJson of
        undefined -> [];
        null -> [];
        Bin when is_binary(Bin) -> json:decode(Bin);
        _ -> []
    end,
    #{
        id => Id,
        submitter_id => SubmitterId,
        category => Category,
        domain => Domain,
        tags => Tags,
        title => Title,
        description => Desc,
        bad_example => BadEx,
        good_example => GoodEx,
        context => Context,
        severity => Severity,
        confidence => Confidence,
        source => Source,
        status => Status,
        validator_id => ValidatorId,
        endorsement_count => EndCount,
        dispute_count => DispCount,
        submitted_at => SubmittedAt,
        validated_at => ValidatedAt
    }.
