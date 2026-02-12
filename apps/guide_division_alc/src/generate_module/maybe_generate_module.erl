%%% @doc maybe_generate_module handler
-module(maybe_generate_module).
-include_lib("evoq/include/evoq.hrl").
-export([handle/1, handle/2, dispatch/1]).

handle(Cmd) -> handle(Cmd, #{}).
handle(Cmd, Context) ->
    case generate_module_v1:validate(Cmd) of
        {ok, _} ->
            ModuleName = generate_module_v1:get_module_name(Cmd),
            GenMods = maps:get(generated_modules, Context, #{}),
            case maps:is_key(ModuleName, GenMods) of
                true -> {error, module_already_generated};
                false ->
                    Event = module_generated_v1:new(#{
                        division_id => generate_module_v1:get_division_id(Cmd),
                        module_name => ModuleName,
                        module_type => generate_module_v1:get_module_type(Cmd),
                        path => generate_module_v1:get_path(Cmd)}),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = generate_module_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{command_type = generate_module, aggregate_type = division_aggregate,
        aggregate_id = DivisionId, payload = generate_module_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined, correlation_id = undefined},
    Opts = #{store_id => dev_studio_store, adapter => reckon_evoq_adapter, consistency => eventual},
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
