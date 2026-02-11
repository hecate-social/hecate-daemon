-module(maybe_generate_module).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case generate_module_v1:validate(Cmd) of
        ok ->
            ModuleName = generate_module_v1:get_module_name(Cmd),
            GeneratedModules = maps:get(generated_modules, Context, #{}),
            case maps:is_key(ModuleName, GeneratedModules) of
                true ->
                    {error, module_already_generated};
                false ->
                    Event = module_generated_v1:new(#{
                        division_id => generate_module_v1:get_division_id(Cmd),
                        module_name => ModuleName,
                        module_type => generate_module_v1:get_module_type(Cmd),
                        file_path => generate_module_v1:get_file_path(Cmd),
                        content => generate_module_v1:get_content(Cmd),
                        description => generate_module_v1:get_description(Cmd),
                        generated_by => generate_module_v1:get_generated_by(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = generate_module_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = generate_module,
        aggregate_type = generation_aggregate,
        aggregate_id = DivisionId,
        payload = generate_module_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => generation_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => generate_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

generate_command_id(DivisionId, Timestamp) ->
    Unique = integer_to_binary(erlang:unique_integer([positive])),
    Hash = crypto:hash(sha256, <<DivisionId/binary, (integer_to_binary(Timestamp))/binary, "-", Unique/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
