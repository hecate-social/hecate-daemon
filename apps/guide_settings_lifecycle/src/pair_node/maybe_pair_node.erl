%%% @doc Handler for pair_node command
-module(maybe_pair_node).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{github_user := GithubUser} = Payload) ->
    Realm = maps:get(realm, Payload, <<"io.macula">>),
    PairedAt = maps:get(paired_at, Payload, erlang:system_time(millisecond)),
    Cmd = pair_node_v1:new(GithubUser, Realm, PairedAt),
    handle(Cmd).

-spec handle(pair_node_v1:pair_node_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{github_user := GithubUser, realm := Realm, paired_at := PairedAt}
        = pair_node_v1:to_map(Command),
    case byte_size(GithubUser) of
        0 -> {error, github_user_required};
        _ ->
            Event = node_paired_v1:new(GithubUser, Realm, PairedAt),
            {ok, [node_paired_v1:to_map(Event)]}
    end.

-spec dispatch(pair_node_v1:pair_node_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    StreamId = settings_aggregate:stream_id(),
    CmdMap = pair_node_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = pair_node,
        aggregate_type = settings_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => pair_node},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => settings_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
