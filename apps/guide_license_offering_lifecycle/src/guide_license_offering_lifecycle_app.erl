%%% @doc guide_license_offering_lifecycle application behaviour
-module(guide_license_offering_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    {ok, Pid} = guide_license_offering_lifecycle_sup:start_link(),
    %% Advertise catch-up replay RPC for remote consumers
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    mesh_catch_up:advertise_replay(Realm, license_offerings_store, <<"license_offerings">>),
    {ok, Pid}.

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
