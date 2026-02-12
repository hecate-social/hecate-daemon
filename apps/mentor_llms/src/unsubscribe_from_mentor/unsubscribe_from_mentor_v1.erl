%%% @doc unsubscribe_from_mentor_v1 command
%%% Unsubscribes from a mentor.
-module(unsubscribe_from_mentor_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_subscriber_id/1, get_mentor_id/1]).

-record(unsubscribe_from_mentor_v1, {
    subscriber_id :: binary(),
    mentor_id     :: binary()
}).

-export_type([unsubscribe_from_mentor_v1/0]).
-opaque unsubscribe_from_mentor_v1() :: #unsubscribe_from_mentor_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, unsubscribe_from_mentor_v1()} | {error, term()}.
new(#{mentor_id := MId} = Params) ->
    SubscriberId = case maps:find(subscriber_id, Params) of
        {ok, V} -> V;
        error   -> hecate_identity:agent_id()
    end,
    Cmd = #unsubscribe_from_mentor_v1{
        subscriber_id = SubscriberId,
        mentor_id = MId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(unsubscribe_from_mentor_v1()) -> {ok, unsubscribe_from_mentor_v1()} | {error, term()}.
validate(#unsubscribe_from_mentor_v1{subscriber_id = SId}) when not is_binary(SId) ->
    {error, invalid_subscriber_id};
validate(#unsubscribe_from_mentor_v1{mentor_id = MId}) when not is_binary(MId) ->
    {error, invalid_mentor_id};
validate(#unsubscribe_from_mentor_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(unsubscribe_from_mentor_v1()) -> map().
to_map(#unsubscribe_from_mentor_v1{} = Cmd) ->
    #{
        command_type => <<"unsubscribe_from_mentor">>,
        subscriber_id => Cmd#unsubscribe_from_mentor_v1.subscriber_id,
        mentor_id => Cmd#unsubscribe_from_mentor_v1.mentor_id
    }.

-spec from_map(map()) -> {ok, unsubscribe_from_mentor_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_subscriber_id(#unsubscribe_from_mentor_v1{subscriber_id = V}) -> V.
get_mentor_id(#unsubscribe_from_mentor_v1{mentor_id = V}) -> V.
