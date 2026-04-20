%%% @doc Handler for initiate_repo command.
%%%
%%% Validates payload, emits `repo_initiated_v1`. On-disk bare repo
%%% creation and mesh catalog advertisement land in Phase 2
%%% (`serve_git_over_mesh`).
%%% @end
-module(maybe_initiate_repo).

-export([handle/1, handle_from_map/1, dispatch/1]).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Map) ->
    case initiate_repo_v1:from_map(Map) of
        {ok, Cmd}        -> handle(Cmd);
        {error, _} = Err -> Err
    end.

-spec handle(initiate_repo_v1:initiate_repo_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    Map = initiate_repo_v1:to_map(Command),
    case validate(Map) of
        ok ->
            Event = repo_initiated_v1:new(Map),
            {ok, [repo_initiated_v1:to_map(Event)]};
        {error, _} = Err ->
            Err
    end.

-spec dispatch(initiate_repo_v1:initiate_repo_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    RepoId   = initiate_repo_v1:get_repo_id(Cmd),
    StreamId = repo_aggregate:stream_id(RepoId),
    CmdMap   = initiate_repo_v1:to_map(Cmd),
    EvoqCmd  = #evoq_command{
        command_type   = initiate_repo,
        aggregate_type = repo_aggregate,
        aggregate_id   = StreamId,
        payload        = CmdMap#{command_type => initiate_repo},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => repo_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).

%% Internal

validate(#{realm := R, name := N, owner_did := D, repo_id := Id,
           visibility := Vis}) ->
    case {byte_size(R), byte_size(N), byte_size(D), byte_size(Id), Vis} of
        {0, _, _, _, _} -> {error, realm_required};
        {_, 0, _, _, _} -> {error, name_required};
        {_, _, 0, _, _} -> {error, owner_did_required};
        {_, _, _, 0, _} -> {error, repo_id_required};
        {_, _, _, _, V} when V =/= <<"public">>, V =/= <<"private">> ->
            {error, invalid_visibility};
        _ -> ok
    end;
validate(_) -> {error, missing_fields}.
