%%% @doc Projection: license_published_v1 -> catalog ETS read model.
%%% Marks a catalog entry as published.
-module(license_published_v1_to_catalog).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, catalog).

interested_in() -> [<<"license_published_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    LicenseId = gf(license_id, Data),
    case find_by_license_id(LicenseId) of
        {ok, PluginId, Existing} ->
            Updated = Existing#{
                published_at => gf(published_at, Data),
                status       => maps:get(status, Existing) bor 4,
                status_label => <<"Published">>
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        not_found ->
            {ok, State, RM}
    end.

find_by_license_id(LicenseId) ->
    All = ets:tab2list(catalog),
    case [E || {_K, #{license_id := LId} = E} <- All, LId =:= LicenseId] of
        [#{plugin_id := PId} = Entry | _] -> {ok, PId, Entry};
        [] -> not_found
    end.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
