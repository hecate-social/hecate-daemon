%%% @doc Projection: learning_submitted_v1 -> learnings table
-module(learning_submitted_v1_to_learnings).

-export([project/1]).

%% @doc Project learning_submitted_v1 event to learnings table
-spec project(map()) -> ok | {error, term()}.
project(#{learning_id := LId, submitter_id := SId, category := Cat,
          domain := Dom, title := Title} = E) ->
    Tags = iolist_to_binary(json:encode(maps:get(tags, E, []))),
    Sql = "INSERT OR REPLACE INTO learnings "
          "(id, submitter_id, category, domain, tags, title, description, "
          "bad_example, good_example, context, severity, confidence, source, "
          "status, submitted_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)",
    project_llm_mentorships_store:execute(Sql, [
        LId, SId, Cat, Dom, Tags, Title,
        maps:get(description, E, undefined),
        maps:get(bad_example, E, undefined),
        maps:get(good_example, E, undefined),
        maps:get(context, E, undefined),
        maps:get(severity, E, <<"suggestion">>),
        maps:get(confidence, E, 0.5),
        maps:get(source, E, <<"discovered">>),
        1,  %% SUBMITTED flag
        maps:get(submitted_at, E, erlang:system_time(millisecond))
    ]).
