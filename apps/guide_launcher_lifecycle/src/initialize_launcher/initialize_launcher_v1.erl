%%% @doc initialize_launcher_v1 command
%%% Initializes the launcher singleton with default groups.
-module(initialize_launcher_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).

-record(initialize_launcher_v1, {
    placeholder :: undefined
}).

-export_type([initialize_launcher_v1/0]).
-opaque initialize_launcher_v1() :: #initialize_launcher_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initialize_launcher_v1()} | {error, term()}.
new(#{}) ->
    {ok, #initialize_launcher_v1{placeholder = undefined}};
new(_) ->
    {ok, #initialize_launcher_v1{placeholder = undefined}}.

-spec validate(initialize_launcher_v1()) -> {ok, initialize_launcher_v1()} | {error, term()}.
validate(#initialize_launcher_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initialize_launcher_v1()) -> map().
to_map(#initialize_launcher_v1{}) ->
    #{
        <<"command_type">> => <<"initialize_launcher">>
    }.

-spec from_map(map()) -> {ok, initialize_launcher_v1()} | {error, term()}.
from_map(_Map) ->
    {ok, #initialize_launcher_v1{placeholder = undefined}}.
