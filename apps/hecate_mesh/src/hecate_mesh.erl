-module(hecate_mesh).

-export([
    publish/2,
    subscribe/2,
    unsubscribe/1,
    advertise/2,
    call/3,
    call/4,
    get_client/0,
    get_status/0,
    is_connected/0,
    discover_subscribers/1,
    get_peers/0,
    get_proof_results/0,
    rerun_proof/0
]).

-spec publish(binary(), map()) -> ok | {error, term()}.
publish(Topic, Payload) ->
    hecate_mesh_client:publish(Topic, Payload).

-spec subscribe(binary(), fun()) -> {ok, reference()} | {error, term()}.
subscribe(Topic, Callback) ->
    hecate_mesh_client:subscribe(Topic, Callback).

-spec unsubscribe(reference()) -> ok | {error, term()}.
unsubscribe(SubRef) ->
    hecate_mesh_client:unsubscribe(SubRef).

-spec advertise(binary(), fun()) -> {ok, reference()} | {error, term()}.
advertise(Procedure, Handler) ->
    hecate_mesh_client:advertise(Procedure, Handler).

-spec call(binary(), map(), timeout()) -> {ok, term()} | {error, term()}.
call(Procedure, Args, Timeout) ->
    hecate_mesh_client:call(Procedure, Args, Timeout).

-spec call(binary(), map(), map(), timeout()) -> {ok, term()} | {error, term()}.
call(Procedure, Args, _Opts, Timeout) ->
    hecate_mesh_client:call(Procedure, Args, Timeout).

-spec get_client() -> {ok, pid()} | {error, term()}.
get_client() ->
    hecate_mesh_client:get_client().

-spec get_status() -> {ok, map()} | {error, term()}.
get_status() ->
    hecate_mesh_client:get_status().

-spec is_connected() -> boolean().
is_connected() ->
    case hecate_mesh_client:get_client() of
        {ok, Pid} when is_pid(Pid) -> true;
        _ -> false
    end.

-spec discover_subscribers(binary()) -> {ok, list()} | {error, term()}.
discover_subscribers(Topic) ->
    hecate_mesh_client:discover_subscribers(Topic).

-spec get_peers() -> {ok, list()}.
get_peers() ->
    %% In relay mode, peers are managed by the relay, not tracked locally.
    %% The relay /status endpoint exposes connected nodes.
    {ok, []}.

-spec get_proof_results() -> map().
get_proof_results() ->
    mesh_proof_coordinator:get_proof_results().

-spec rerun_proof() -> ok.
rerun_proof() ->
    mesh_proof_coordinator:rerun_probes().
