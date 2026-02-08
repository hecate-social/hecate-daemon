%%% @doc term_defined_v1 event
%%% Emitted when a ubiquitous language term is defined.
-module(term_defined_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_term_id/1, get_term/1,
         get_definition/1, get_defined_at/1]).

-record(term_defined_v1, {
    cartwheel_id :: binary(),
    term_id    :: binary(),
    term       :: binary(),
    definition :: binary(),
    defined_at :: integer()
}).

-export_type([term_defined_v1/0]).
-opaque term_defined_v1() :: #term_defined_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> term_defined_v1().
new(#{cartwheel_id := CartwheelId, term_id := TermId,
      term := Term, definition := Definition} = _Params) ->
    #term_defined_v1{
        cartwheel_id = CartwheelId,
        term_id = TermId,
        term = Term,
        definition = Definition,
        defined_at = erlang:system_time(millisecond)
    }.

-spec to_map(term_defined_v1()) -> map().
to_map(#term_defined_v1{} = E) ->
    #{
        event_type => <<"term_defined_v1">>,
        cartwheel_id => E#term_defined_v1.cartwheel_id,
        term_id => E#term_defined_v1.term_id,
        term => E#term_defined_v1.term,
        definition => E#term_defined_v1.definition,
        defined_at => E#term_defined_v1.defined_at
    }.

-spec from_map(map()) -> {ok, term_defined_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId, term_id := TermId,
           term := Term, definition := Definition} = Map) ->
    {ok, #term_defined_v1{
        cartwheel_id = CartwheelId,
        term_id = TermId,
        term = Term,
        definition = Definition,
        defined_at = maps:get(defined_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#term_defined_v1{cartwheel_id = V}) -> V.
get_term_id(#term_defined_v1{term_id = V}) -> V.
get_term(#term_defined_v1{term = V}) -> V.
get_definition(#term_defined_v1{definition = V}) -> V.
get_defined_at(#term_defined_v1{defined_at = V}) -> V.
