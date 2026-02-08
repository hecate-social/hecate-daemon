%%% @doc resolve_incident_v1 command
%%% Resolves a previously reported incident for a project.
-module(resolve_incident_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_incident_id/1, get_resolution/1]).

-record(resolve_incident_v1, {
    cartwheel_id  :: binary(),
    incident_id :: binary(),
    resolution  :: binary()
}).

-export_type([resolve_incident_v1/0]).
-opaque resolve_incident_v1() :: #resolve_incident_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, resolve_incident_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId, incident_id := IncidentId, resolution := Resolution} = _Params) ->
    Cmd = #resolve_incident_v1{
        cartwheel_id = CartwheelId,
        incident_id = IncidentId,
        resolution = Resolution
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(resolve_incident_v1()) -> {ok, resolve_incident_v1()} | {error, term()}.
validate(#resolve_incident_v1{cartwheel_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#resolve_incident_v1{incident_id = I}) when
    not is_binary(I); byte_size(I) =:= 0 ->
    {error, invalid_incident_id};
validate(#resolve_incident_v1{resolution = R}) when
    not is_binary(R); byte_size(R) =:= 0 ->
    {error, invalid_resolution};
validate(#resolve_incident_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(resolve_incident_v1()) -> map().
to_map(#resolve_incident_v1{} = Cmd) ->
    #{
        command_type => <<"resolve_incident">>,
        cartwheel_id => Cmd#resolve_incident_v1.cartwheel_id,
        incident_id => Cmd#resolve_incident_v1.incident_id,
        resolution => Cmd#resolve_incident_v1.resolution
    }.

-spec from_map(map()) -> {ok, resolve_incident_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#resolve_incident_v1{cartwheel_id = V}) -> V.
get_incident_id(#resolve_incident_v1{incident_id = V}) -> V.
get_resolution(#resolve_incident_v1{resolution = V}) -> V.
