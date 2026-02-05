%%% @doc maybe_draft_plan handler
%%% Business logic for drafting a plan during architecture and planning.
%%% Validates the command and dispatches via evoq.
-module(maybe_draft_plan).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle draft_plan_v1 command (business logic only)
-spec handle(draft_plan_v1:draft_plan_v1()) ->
    {ok, [plan_drafted_v1:plan_drafted_v1()]} | {error, term()}.
handle(Cmd) ->
    Title = draft_plan_v1:get_title(Cmd),
    case validate_command(Title) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(draft_plan_v1:draft_plan_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ProjectId = draft_plan_v1:get_project_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(ProjectId, Timestamp),
        command_type = draft_plan,
        aggregate_type = alc_aggregate,
        aggregate_id = <<"alc-", ProjectId/binary>>,
        payload = draft_plan_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => alc_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_alc_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(Title) when is_binary(Title), byte_size(Title) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    plan_drafted_v1:new(#{
        project_id => draft_plan_v1:get_project_id(Cmd),
        plan_id => draft_plan_v1:get_plan_id(Cmd),
        title => draft_plan_v1:get_title(Cmd),
        content_ref => draft_plan_v1:get_content_ref(Cmd)
    }).

generate_command_id(ProjectId, Timestamp) ->
    Hash = crypto:hash(sha256, <<ProjectId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
