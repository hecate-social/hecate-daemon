%%% @doc Projection: license_archived_v1 -> licenses ETS read model.
%%% Sets archived flag and status on existing license.
-module(license_archived_v1_to_licenses).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, licenses).

interested_in() -> [<<"license_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    LicenseId = gf(license_id, Data),
    case evoq_read_model:get(LicenseId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                archived_at  => gf(archived_at, Data),
                status       => maps:get(status, Existing) bor 32,
                status_label => <<"Archived">>
            },
            {ok, RM2} = evoq_read_model:put(LicenseId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
