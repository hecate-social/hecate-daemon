%%% @doc maybe_scaffold_venture_repo handler
%%% Business logic for scaffolding venture repos.
%%% Validates the command and dispatches via evoq.
-module(maybe_scaffold_venture_repo).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle scaffold_venture_repo_v1 command (business logic only)
-spec handle(scaffold_venture_repo_v1:scaffold_venture_repo_v1()) ->
    {ok, [venture_repo_scaffolded_v1:venture_repo_scaffolded_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(scaffold_venture_repo_v1:scaffold_venture_repo_v1(), term()) ->
    {ok, [venture_repo_scaffolded_v1:venture_repo_scaffolded_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    RepoPath = scaffold_venture_repo_v1:get_repo_path(Cmd),
    case validate_command(RepoPath) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(scaffold_venture_repo_v1:scaffold_venture_repo_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    VentureId = scaffold_venture_repo_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = scaffold_venture_repo,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = scaffold_venture_repo_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => venture_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(RepoPath) when is_binary(RepoPath), byte_size(RepoPath) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_repo_path}.

create_event(Cmd) ->
    venture_repo_scaffolded_v1:new(#{
        venture_id => scaffold_venture_repo_v1:get_venture_id(Cmd),
        repo_path => scaffold_venture_repo_v1:get_repo_path(Cmd),
        brief => scaffold_venture_repo_v1:get_brief(Cmd)
    }).
