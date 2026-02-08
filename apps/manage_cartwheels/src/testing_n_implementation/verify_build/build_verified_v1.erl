%%% @doc build_verified_v1 event
%%% Emitted when a build is verified during testing and implementation.
-module(build_verified_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_build_id/1, get_result/1, get_notes/1,
         get_verified_at/1]).

-record(build_verified_v1, {
    cartwheel_id  :: binary(),
    build_id    :: binary(),
    result      :: binary(),
    notes       :: binary() | undefined,
    verified_at :: integer()
}).

-export_type([build_verified_v1/0]).
-opaque build_verified_v1() :: #build_verified_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> build_verified_v1().
new(#{cartwheel_id := CartwheelId, build_id := BuildId, result := Result} = Params) ->
    #build_verified_v1{
        cartwheel_id = CartwheelId,
        build_id = BuildId,
        result = Result,
        notes = maps:get(notes, Params, undefined),
        verified_at = erlang:system_time(millisecond)
    }.

-spec to_map(build_verified_v1()) -> map().
to_map(#build_verified_v1{} = E) ->
    #{
        event_type => <<"build_verified_v1">>,
        cartwheel_id => E#build_verified_v1.cartwheel_id,
        build_id => E#build_verified_v1.build_id,
        result => E#build_verified_v1.result,
        notes => E#build_verified_v1.notes,
        verified_at => E#build_verified_v1.verified_at
    }.

-spec from_map(map()) -> {ok, build_verified_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId, build_id := BuildId, result := Result} = Map) ->
    {ok, #build_verified_v1{
        cartwheel_id = CartwheelId,
        build_id = BuildId,
        result = Result,
        notes = maps:get(notes, Map, undefined),
        verified_at = maps:get(verified_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#build_verified_v1{cartwheel_id = V}) -> V.
get_build_id(#build_verified_v1{build_id = V}) -> V.
get_result(#build_verified_v1{result = V}) -> V.
get_notes(#build_verified_v1{notes = V}) -> V.
get_verified_at(#build_verified_v1{verified_at = V}) -> V.
