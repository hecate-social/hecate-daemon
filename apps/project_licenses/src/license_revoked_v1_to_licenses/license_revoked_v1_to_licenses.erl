%%% @doc Projection: license_revoked_v1 -> licenses ETS read model.
%%% Sets revoked flag and status on existing license.
-module(license_revoked_v1_to_licenses).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, licenses).

interested_in() -> [<<"license_revoked_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                revoked_at   => gf(revoked_at, Data),
                revoked      => 1,
                status       => maps:get(status, Existing) bor 16,
                status_label => <<"Revoked">>
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
