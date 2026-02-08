%%% @doc cartwheel_initiated_v1 event
%%% Emitted when a cartwheel is successfully initiated.
-module(cartwheel_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_torch_id/1, get_context_name/1, get_description/1, get_initiated_at/1]).

-record(cartwheel_initiated_v1, {
    cartwheel_id :: binary(),
    torch_id     :: binary() | undefined,
    context_name :: binary(),
    description  :: binary() | undefined,
    initiated_at :: integer()
}).

-export_type([cartwheel_initiated_v1/0]).
-opaque cartwheel_initiated_v1() :: #cartwheel_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> cartwheel_initiated_v1().
new(#{cartwheel_id := CartwheelId, context_name := Name} = Params) ->
    #cartwheel_initiated_v1{
        cartwheel_id = CartwheelId,
        torch_id = maps:get(torch_id, Params, undefined),
        context_name = Name,
        description = maps:get(description, Params, undefined),
        initiated_at = erlang:system_time(millisecond)
    };
new(#{cartwheel_id := _CartwheelId, name := Name} = Params) ->
    %% Backward compat
    new(Params#{context_name => Name}).

-spec to_map(cartwheel_initiated_v1()) -> map().
to_map(#cartwheel_initiated_v1{} = E) ->
    #{
        event_type => <<"cartwheel_initiated_v1">>,
        cartwheel_id => E#cartwheel_initiated_v1.cartwheel_id,
        torch_id => E#cartwheel_initiated_v1.torch_id,
        context_name => E#cartwheel_initiated_v1.context_name,
        name => E#cartwheel_initiated_v1.context_name,  %% For backward compat
        description => E#cartwheel_initiated_v1.description,
        initiated_at => E#cartwheel_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, cartwheel_initiated_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId} = Map) ->
    ContextName = maps:get(context_name, Map, maps:get(name, Map, undefined)),
    {ok, #cartwheel_initiated_v1{
        cartwheel_id = CartwheelId,
        torch_id = maps:get(torch_id, Map, undefined),
        context_name = ContextName,
        description = maps:get(description, Map, undefined),
        initiated_at = maps:get(initiated_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#cartwheel_initiated_v1{cartwheel_id = V}) -> V.
get_torch_id(#cartwheel_initiated_v1{torch_id = V}) -> V.
get_context_name(#cartwheel_initiated_v1{context_name = V}) -> V.
get_description(#cartwheel_initiated_v1{description = V}) -> V.
get_initiated_at(#cartwheel_initiated_v1{initiated_at = V}) -> V.
