%%% @doc inventory_spoke_v1 command
%%% Inventories a spoke within a dossier during architecture and planning.
-module(inventory_spoke_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_project_id/1, get_spoke_id/1, get_spoke_name/1, get_spoke_type/1,
         get_priority/1, get_dossier_id/1, get_description/1]).

-record(inventory_spoke_v1, {
    project_id  :: binary(),
    spoke_id    :: binary(),
    spoke_name  :: binary(),
    spoke_type  :: binary(),
    priority    :: binary(),
    dossier_id  :: binary(),
    description :: binary() | undefined
}).

-export_type([inventory_spoke_v1/0]).
-opaque inventory_spoke_v1() :: #inventory_spoke_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, inventory_spoke_v1()} | {error, term()}.
new(#{project_id := ProjectId, spoke_name := SpokeName,
      spoke_type := SpokeType, dossier_id := DossierId} = Params) ->
    Cmd = #inventory_spoke_v1{
        project_id = ProjectId,
        spoke_id = maps:get(spoke_id, Params, generate_id()),
        spoke_name = SpokeName,
        spoke_type = SpokeType,
        priority = maps:get(priority, Params, <<"should">>),
        dossier_id = DossierId,
        description = maps:get(description, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(inventory_spoke_v1()) -> {ok, inventory_spoke_v1()} | {error, term()}.
validate(#inventory_spoke_v1{project_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_project_id};
validate(#inventory_spoke_v1{spoke_name = N}) when
    not is_binary(N); byte_size(N) =:= 0 ->
    {error, invalid_spoke_name};
validate(#inventory_spoke_v1{spoke_type = T}) when
    T =/= <<"command">>, T =/= <<"query">>, T =/= <<"projection">>,
    T =/= <<"listener">>, T =/= <<"emitter">>, T =/= <<"process_manager">> ->
    {error, invalid_spoke_type};
validate(#inventory_spoke_v1{priority = Pri}) when
    Pri =/= <<"must">>, Pri =/= <<"should">>,
    Pri =/= <<"could">>, Pri =/= <<"wont">> ->
    {error, invalid_priority};
validate(#inventory_spoke_v1{dossier_id = D}) when
    not is_binary(D); byte_size(D) =:= 0 ->
    {error, invalid_dossier_id};
validate(#inventory_spoke_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(inventory_spoke_v1()) -> map().
to_map(#inventory_spoke_v1{} = Cmd) ->
    #{
        command_type => <<"inventory_spoke">>,
        project_id => Cmd#inventory_spoke_v1.project_id,
        spoke_id => Cmd#inventory_spoke_v1.spoke_id,
        spoke_name => Cmd#inventory_spoke_v1.spoke_name,
        spoke_type => Cmd#inventory_spoke_v1.spoke_type,
        priority => Cmd#inventory_spoke_v1.priority,
        dossier_id => Cmd#inventory_spoke_v1.dossier_id,
        description => Cmd#inventory_spoke_v1.description
    }.

-spec from_map(map()) -> {ok, inventory_spoke_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_project_id(#inventory_spoke_v1{project_id = V}) -> V.
get_spoke_id(#inventory_spoke_v1{spoke_id = V}) -> V.
get_spoke_name(#inventory_spoke_v1{spoke_name = V}) -> V.
get_spoke_type(#inventory_spoke_v1{spoke_type = V}) -> V.
get_priority(#inventory_spoke_v1{priority = V}) -> V.
get_dossier_id(#inventory_spoke_v1{dossier_id = V}) -> V.
get_description(#inventory_spoke_v1{description = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"spk-", Ts/binary, "-", Rand/binary>>.
