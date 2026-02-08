%%% @doc maybe_define_term handler
%%% Business logic for defining a ubiquitous language term.
%%% Validates the command and dispatches via evoq.
-module(maybe_define_term).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle define_term_v1 command (business logic only)
-spec handle(define_term_v1:define_term_v1()) ->
    {ok, [term_defined_v1:term_defined_v1()]} | {error, term()}.
handle(Cmd) ->
    Term = define_term_v1:get_term(Cmd),
    Definition = define_term_v1:get_definition(Cmd),
    case validate_command(Term, Definition) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(define_term_v1:define_term_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = define_term_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = define_term,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = define_term_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => cartwheel_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_cartwheels_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(Term, Definition) when
    is_binary(Term), byte_size(Term) > 0,
    is_binary(Definition), byte_size(Definition) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    term_defined_v1:new(#{
        cartwheel_id => define_term_v1:get_cartwheel_id(Cmd),
        term_id => define_term_v1:get_term_id(Cmd),
        term => define_term_v1:get_term(Cmd),
        definition => define_term_v1:get_definition(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
