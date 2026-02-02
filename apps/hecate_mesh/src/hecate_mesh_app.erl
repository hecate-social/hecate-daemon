-module(hecate_mesh_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% Get mesh configuration
    BootstrapNodes = application:get_env(hecate_mesh, bootstrap_nodes, ["boot.macula.io:4433"]),
    Realm = application:get_env(hecate_mesh, realm, <<"io.macula">>),
    AgentIdentity = application:get_env(hecate_mesh, agent_identity, <<"mri:agent:io.macula/hecate">>),

    io:format("~n🌐 Connecting to Macula mesh...~n"),
    io:format("   Bootstrap: ~p~n", [BootstrapNodes]),
    io:format("   Realm: ~s~n", [Realm]),
    io:format("   Identity: ~s~n~n", [AgentIdentity]),

    %% Start supervisor (will start mesh client)
    {ok, Pid} = hecate_mesh_sup:start_link(),

    io:format("✅ Mesh client started~n~n"),

    {ok, Pid}.

stop(_State) ->
    io:format("~n🔌 Disconnecting from Macula mesh...~n~n"),
    ok.
