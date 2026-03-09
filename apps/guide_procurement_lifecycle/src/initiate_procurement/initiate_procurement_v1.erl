%%% @doc initiate_procurement_v1 command
%%% Birth event for procurement lifecycle.
-module(initiate_procurement_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_procurement_id/1, get_consumer_id/1, get_offering_id/1, get_plugin_id/1,
         get_author_id/1]).

-record(initiate_procurement_v1, {
    procurement_id :: binary(),
    consumer_id    :: binary(),
    offering_id    :: binary(),
    plugin_id      :: binary(),
    author_id      :: binary()
}).

-export_type([initiate_procurement_v1/0]).
-opaque initiate_procurement_v1() :: #initiate_procurement_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_procurement_v1()} | {error, term()}.
new(#{consumer_id := ConsumerId, offering_id := OfferingId,
      plugin_id := PluginId, author_id := AuthorId}) ->
    ProcurementId = <<"procurement-", ConsumerId/binary, "-", PluginId/binary>>,
    {ok, #initiate_procurement_v1{
        procurement_id = ProcurementId,
        consumer_id = ConsumerId,
        offering_id = OfferingId,
        plugin_id = PluginId,
        author_id = AuthorId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_procurement_v1()) -> {ok, initiate_procurement_v1()} | {error, term()}.
validate(#initiate_procurement_v1{consumer_id = ConsumerId}) when
    not is_binary(ConsumerId); byte_size(ConsumerId) =:= 0 ->
    {error, invalid_consumer_id};
validate(#initiate_procurement_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#initiate_procurement_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#initiate_procurement_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_procurement_v1()) -> map().
to_map(#initiate_procurement_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"initiate_procurement">>,
        <<"procurement_id">> => Cmd#initiate_procurement_v1.procurement_id,
        <<"consumer_id">> => Cmd#initiate_procurement_v1.consumer_id,
        <<"offering_id">> => Cmd#initiate_procurement_v1.offering_id,
        <<"plugin_id">> => Cmd#initiate_procurement_v1.plugin_id,
        <<"author_id">> => Cmd#initiate_procurement_v1.author_id
    }.

-spec from_map(map()) -> {ok, initiate_procurement_v1()} | {error, term()}.
from_map(Map) ->
    ConsumerId = hecate_api_utils:get_field(consumer_id, Map),
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    AuthorId = hecate_api_utils:get_field(author_id, Map),
    case {ConsumerId, OfferingId, PluginId, AuthorId} of
        {undefined, _, _, _} -> {error, missing_required_fields};
        {_, undefined, _, _} -> {error, missing_required_fields};
        {_, _, undefined, _} -> {error, missing_required_fields};
        {_, _, _, undefined} -> {error, missing_required_fields};
        _ ->
            ProcurementId = <<"procurement-", ConsumerId/binary, "-", PluginId/binary>>,
            {ok, #initiate_procurement_v1{
                procurement_id = ProcurementId,
                consumer_id = ConsumerId,
                offering_id = OfferingId,
                plugin_id = PluginId,
                author_id = AuthorId
            }}
    end.

%% Accessors
-spec get_procurement_id(initiate_procurement_v1()) -> binary().
get_procurement_id(#initiate_procurement_v1{procurement_id = V}) -> V.

-spec get_consumer_id(initiate_procurement_v1()) -> binary().
get_consumer_id(#initiate_procurement_v1{consumer_id = V}) -> V.

-spec get_offering_id(initiate_procurement_v1()) -> binary().
get_offering_id(#initiate_procurement_v1{offering_id = V}) -> V.

-spec get_plugin_id(initiate_procurement_v1()) -> binary().
get_plugin_id(#initiate_procurement_v1{plugin_id = V}) -> V.

-spec get_author_id(initiate_procurement_v1()) -> binary().
get_author_id(#initiate_procurement_v1{author_id = V}) -> V.
