%%% @doc Handler for issue_license_v1.
%%%
%%% Validates the command has all mandatory crypto fields, constructs
%%% the event, returns it for evoq to persist on the issuer's aggregate
%%% stream `issued-license-{license_id}`.
%%% @end
-module(maybe_issue_license).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    case validate(Payload) of
        ok ->
            {ok, Event} = license_issued_v1:new(build_event_map(Payload)),
            {ok, [license_issued_v1:to_map(Event)]};
        {error, _} = Err ->
            Err
    end.

-spec handle(issue_license_v1:issue_license_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(issue_license_v1:to_map(Cmd)).

-spec dispatch(issue_license_v1:issue_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Payload = issue_license_v1:to_map(Cmd),
    LicenseId = maps:get(license_id, Payload),
    StreamId = issued_license_aggregate:stream_id(LicenseId),
    EvoqCmd = #evoq_command{
        command_type   = issue_license_v1,
        aggregate_type = issued_license_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => issue_license_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => share_licenses_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).

%% --- Internal ---

validate(Payload) ->
    Required = [license_id, file_id, grantee, wrap_strategy,
                wrapped_cek, origin_cek_sealed,
                issuer_did, realm, batch_id],
    check_required(Required, Payload).

check_required([], _Payload) -> ok;
check_required([K | Rest], Payload) ->
    case maps:get(K, Payload, undefined) of
        undefined -> {error, {missing, K}};
        <<>>      -> {error, {empty, K}};
        _         -> check_required(Rest, Payload)
    end.

build_event_map(Payload) ->
    Now = erlang:system_time(millisecond),
    IssuedAt  = maps:get(issued_at,  Payload, Now),
    ExpiresAt = maps:get(expires_at, Payload, IssuedAt + ten_years_ms()),
    maps:merge(Payload, #{issued_at => IssuedAt, expires_at => ExpiresAt}).

ten_years_ms() -> 10 * 365 * 24 * 3600 * 1000.
