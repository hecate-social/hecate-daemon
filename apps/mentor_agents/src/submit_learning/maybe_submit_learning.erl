%%% @doc maybe_submit_learning handler
%%% Business logic for submitting learnings.
%%% Validates the command and dispatches via evoq.
-module(maybe_submit_learning).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle submit_learning_v1 command (business logic only)
-spec handle(submit_learning_v1:submit_learning_v1()) ->
    {ok, [learning_submitted_v1:learning_submitted_v1()]} | {error, term()}.
handle(Cmd) ->
    Category = submit_learning_v1:get_category(Cmd),
    Title = submit_learning_v1:get_title(Cmd),
    case validate_command(Category, Title) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(submit_learning_v1:submit_learning_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LearningId = submit_learning_v1:get_learning_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(LearningId, Timestamp),
        command_type = submit_learning,
        aggregate_type = learning_aggregate,
        aggregate_id = <<"learning-", LearningId/binary>>,
        payload = submit_learning_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => learning_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => mentor_agents_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(Category, Title) when
    is_binary(Category), is_binary(Title), byte_size(Title) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    learning_submitted_v1:new(#{
        learning_id => submit_learning_v1:get_learning_id(Cmd),
        submitter_id => submit_learning_v1:get_submitter_id(Cmd),
        category => submit_learning_v1:get_category(Cmd),
        domain => submit_learning_v1:get_domain(Cmd),
        tags => submit_learning_v1:get_tags(Cmd),
        title => submit_learning_v1:get_title(Cmd),
        description => submit_learning_v1:get_description(Cmd),
        bad_example => submit_learning_v1:get_bad_example(Cmd),
        good_example => submit_learning_v1:get_good_example(Cmd),
        context => submit_learning_v1:get_context(Cmd),
        severity => submit_learning_v1:get_severity(Cmd),
        confidence => submit_learning_v1:get_confidence(Cmd),
        source => submit_learning_v1:get_source(Cmd)
    }).

generate_command_id(LearningId, Timestamp) ->
    Hash = crypto:hash(sha256, <<LearningId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
