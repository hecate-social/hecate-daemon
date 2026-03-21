%%% @doc Projection: realm_credentials_secured_v1 -> realm_credentials ETS.
%%%
%%% Stores encrypted credentials keyed by membership_id.
%%% Credentials remain encrypted in ETS — decryption happens at query time.
-module(credentials_secured_v1_to_credentials).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, realm_credentials).

interested_in() ->
    [<<"realm_credentials_secured_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = _Event, _Metadata, State, RM) ->
    MembershipId = hecate_api_utils:get_field(membership_id, Data),
    EncCreds = hecate_api_utils:get_field(encrypted_credentials, Data),
    SecuredAt = hecate_api_utils:get_field(secured_at, Data),
    Entry = #{
        membership_id => MembershipId,
        encrypted_credentials => EncCreds,
        secured_at => SecuredAt
    },
    {ok, RM2} = evoq_read_model:put(MembershipId, Entry, RM),
    {ok, State, RM2}.
