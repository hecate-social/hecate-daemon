%%% @doc approve_plan_v1 command
%%% Approves a plan during the architecture and planning phase.
-module(approve_plan_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_plan_id/1]).

-record(approve_plan_v1, {
    cartwheel_id :: binary(),
    plan_id    :: binary()
}).

-export_type([approve_plan_v1/0]).
-opaque approve_plan_v1() :: #approve_plan_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, approve_plan_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId, plan_id := PlanId} = _Params) ->
    Cmd = #approve_plan_v1{
        cartwheel_id = CartwheelId,
        plan_id = PlanId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(approve_plan_v1()) -> {ok, approve_plan_v1()} | {error, term()}.
validate(#approve_plan_v1{cartwheel_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#approve_plan_v1{plan_id = Pl}) when
    not is_binary(Pl); byte_size(Pl) =:= 0 ->
    {error, invalid_plan_id};
validate(#approve_plan_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(approve_plan_v1()) -> map().
to_map(#approve_plan_v1{} = Cmd) ->
    #{
        command_type => <<"approve_plan">>,
        cartwheel_id => Cmd#approve_plan_v1.cartwheel_id,
        plan_id => Cmd#approve_plan_v1.plan_id
    }.

-spec from_map(map()) -> {ok, approve_plan_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#approve_plan_v1{cartwheel_id = V}) -> V.
get_plan_id(#approve_plan_v1{plan_id = V}) -> V.
