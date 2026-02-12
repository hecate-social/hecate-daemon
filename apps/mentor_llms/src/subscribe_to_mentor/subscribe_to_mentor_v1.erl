%%% @doc subscribe_to_mentor_v1 command
%%% Subscribes to a mentor for learning updates.
-module(subscribe_to_mentor_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_subscriber_id/1, get_mentor_id/1]).

-record(subscribe_to_mentor_v1, {
    subscriber_id :: binary(),
    mentor_id     :: binary()
}).

-export_type([subscribe_to_mentor_v1/0]).
-opaque subscribe_to_mentor_v1() :: #subscribe_to_mentor_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, subscribe_to_mentor_v1()} | {error, term()}.
new(#{mentor_id := MId} = Params) ->
    SubscriberId = case maps:find(subscriber_id, Params) of
        {ok, V} -> V;
        error   -> hecate_identity:agent_id()
    end,
    Cmd = #subscribe_to_mentor_v1{
        subscriber_id = SubscriberId,
        mentor_id = MId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(subscribe_to_mentor_v1()) -> {ok, subscribe_to_mentor_v1()} | {error, term()}.
validate(#subscribe_to_mentor_v1{subscriber_id = SId}) when not is_binary(SId) ->
    {error, invalid_subscriber_id};
validate(#subscribe_to_mentor_v1{mentor_id = MId}) when not is_binary(MId) ->
    {error, invalid_mentor_id};
validate(#subscribe_to_mentor_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(subscribe_to_mentor_v1()) -> map().
to_map(#subscribe_to_mentor_v1{} = Cmd) ->
    #{
        command_type => <<"subscribe_to_mentor">>,
        subscriber_id => Cmd#subscribe_to_mentor_v1.subscriber_id,
        mentor_id => Cmd#subscribe_to_mentor_v1.mentor_id
    }.

-spec from_map(map()) -> {ok, subscribe_to_mentor_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_subscriber_id(#subscribe_to_mentor_v1{subscriber_id = V}) -> V.
get_mentor_id(#subscribe_to_mentor_v1{mentor_id = V}) -> V.
