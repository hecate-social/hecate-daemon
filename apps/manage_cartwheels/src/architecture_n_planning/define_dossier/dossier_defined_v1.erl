%%% @doc dossier_defined_v1 event
%%% Emitted when a dossier is defined during architecture and planning.
-module(dossier_defined_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_cartwheel_id/1, get_dossier_id/1, get_dossier_name/1,
         get_stream_pattern/1, get_description/1, get_defined_at/1]).

-record(dossier_defined_v1, {
    cartwheel_id     :: binary(),
    dossier_id     :: binary(),
    dossier_name   :: binary(),
    stream_pattern :: binary(),
    description    :: binary() | undefined,
    defined_at     :: integer()
}).

-export_type([dossier_defined_v1/0]).
-opaque dossier_defined_v1() :: #dossier_defined_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> dossier_defined_v1().
new(#{cartwheel_id := CartwheelId, dossier_id := DossierId,
      dossier_name := DossierName} = Params) ->
    #dossier_defined_v1{
        cartwheel_id = CartwheelId,
        dossier_id = DossierId,
        dossier_name = DossierName,
        stream_pattern = maps:get(stream_pattern, Params, <<"default">>),
        description = maps:get(description, Params, undefined),
        defined_at = erlang:system_time(millisecond)
    }.

-spec to_map(dossier_defined_v1()) -> map().
to_map(#dossier_defined_v1{} = E) ->
    #{
        event_type => <<"dossier_defined_v1">>,
        cartwheel_id => E#dossier_defined_v1.cartwheel_id,
        dossier_id => E#dossier_defined_v1.dossier_id,
        dossier_name => E#dossier_defined_v1.dossier_name,
        stream_pattern => E#dossier_defined_v1.stream_pattern,
        description => E#dossier_defined_v1.description,
        defined_at => E#dossier_defined_v1.defined_at
    }.

-spec from_map(map()) -> {ok, dossier_defined_v1()} | {error, term()}.
from_map(#{cartwheel_id := CartwheelId, dossier_id := DossierId,
           dossier_name := DossierName} = Map) ->
    {ok, #dossier_defined_v1{
        cartwheel_id = CartwheelId,
        dossier_id = DossierId,
        dossier_name = DossierName,
        stream_pattern = maps:get(stream_pattern, Map, <<"default">>),
        description = maps:get(description, Map, undefined),
        defined_at = maps:get(defined_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_cartwheel_id(#dossier_defined_v1{cartwheel_id = V}) -> V.
get_dossier_id(#dossier_defined_v1{dossier_id = V}) -> V.
get_dossier_name(#dossier_defined_v1{dossier_name = V}) -> V.
get_stream_pattern(#dossier_defined_v1{stream_pattern = V}) -> V.
get_description(#dossier_defined_v1{description = V}) -> V.
get_defined_at(#dossier_defined_v1{defined_at = V}) -> V.
