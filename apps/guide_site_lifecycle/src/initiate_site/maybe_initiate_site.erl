%%% @doc Handler for initiate_site command
-module(maybe_initiate_site).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    SiteId = maps:get(site_id, Payload, <<>>),
    InitiatedBy = maps:get(initiated_by, Payload, <<>>),
    InitiatedAt = maps:get(initiated_at, Payload, erlang:system_time(millisecond)),
    Cmd = initiate_site_v1:new(SiteId, InitiatedBy, InitiatedAt),
    handle(Cmd).

-spec handle(initiate_site_v1:initiate_site_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{site_id := SiteId, initiated_by := InitiatedBy} =
        initiate_site_v1:to_map(Command),
    case {byte_size(SiteId), byte_size(InitiatedBy)} of
        {0, _} -> {error, site_id_required};
        {_, 0} -> {error, initiated_by_required};
        _ ->
            Event = initiate_site_v1:to_map(Command),
            {ok, [Event#{event_type => <<"site_initiated_v1">>}]}
    end.

-spec dispatch(initiate_site_v1:initiate_site_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{site_id := SiteId} = initiate_site_v1:to_map(Cmd),
    StreamId = site_aggregate:stream_id(SiteId),
    CmdMap = initiate_site_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = initiate_site,
        aggregate_type = site_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => initiate_site},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    case evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => site_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }) of
        {ok, V, Events} ->
            %% Auto-admit the initiating node
            admit_self(SiteId),
            {ok, V, Events};
        Error ->
            Error
    end.

%% @private Admit the local node to the newly created site.
admit_self(SiteId) ->
    NodeName = atom_to_binary(node()),
    AdmitCmd = admit_node_v1:new(NodeName, erlang:system_time(millisecond)),
    case maybe_admit_node:dispatch(SiteId, AdmitCmd) of
        {ok, _, _} ->
            logger:info("[site] Node admitted: ~s", [NodeName]);
        {error, Reason} ->
            logger:warning("[site] Failed to auto-admit self: ~p", [Reason])
    end.
