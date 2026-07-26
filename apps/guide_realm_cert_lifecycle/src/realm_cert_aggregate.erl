%%% @doc Aggregate for the realm_cert domain.
%%%
%%% Singleton per daemon. Stream: `realm_cert'. Accepts the
%%% `acquire_provisional_cert_v1' command, produces a
%%% `provisional_cert_acquired_v1' event recording where the bytes
%%% landed on disk and when they expire.
%%% @end
-module(realm_cert_aggregate).
-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/0]).

-spec state_module() -> module().
state_module() -> realm_cert_state.

-spec stream_id() -> binary().
stream_id() ->
    <<"realm_cert">>.

init(AggregateId) ->
    {ok, realm_cert_state:new(AggregateId)}.

execute(_State, #{command_type := acquire_provisional_cert_v1} = Payload) ->
    maybe_acquire_provisional_cert:handle_from_map(Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    realm_cert_state:apply_event(State, Event).
