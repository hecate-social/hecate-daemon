%%% @doc API handler: POST /api/arcade/gladiators/stables/:stable_id/halt
%%% Halts a running training session.
-module(halt_training_api).

-export([init/2]).

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            StableId = cowboy_req:binding(stable_id, Req0),
            handle_halt(StableId, Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

handle_halt(StableId, Req) ->
    case persistent_term:get({gladiator_training, StableId}, undefined) of
        undefined ->
            hecate_api_utils:not_found(Req);
        Pid when is_pid(Pid) ->
            case is_process_alive(Pid) of
                true ->
                    ok = training_proc:halt(Pid),
                    hecate_api_utils:json_ok(200, #{
                        stable_id => StableId,
                        status => <<"halted">>
                    }, Req);
                false ->
                    hecate_api_utils:not_found(Req)
            end
    end.
