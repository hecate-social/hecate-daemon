%%% @doc grant_capability_v1 command
%%% Command to grant a UCAN capability token to an agent.
-module(grant_capability_v1).

-export([new/7, to_map/1, from_map/1]).
-export([get_capability_id/1, get_issuer/1, get_audience/1, get_resource/1,
         get_actions/1, get_expires_at/1, get_granted_at/1]).

-record(grant_capability_v1, {
    capability_id :: binary(),    % Unique capability identifier
    issuer :: binary(),           % MRI of issuer
    audience :: binary(),         % MRI of recipient
    resource :: binary(),         % Resource URI
    actions :: [binary()],        % Allowed actions (read, write, execute, etc.)
    expires_at :: integer(),      % Expiration timestamp
    granted_at :: integer()       % Grant timestamp
}).

-opaque grant_capability_v1() :: #grant_capability_v1{}.
-export_type([grant_capability_v1/0]).

%% @doc Create a new grant_capability command.
-spec new(binary(), binary(), binary(), binary(), [binary()], integer(), integer()) ->
    grant_capability_v1().
new(CapabilityId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    #grant_capability_v1{
        capability_id = CapabilityId,
        issuer = Issuer,
        audience = Audience,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt
    }.

%% @doc Convert command to map.
-spec to_map(grant_capability_v1()) -> map().
to_map(#grant_capability_v1{
    capability_id = CapId,
    issuer = Issuer,
    audience = Audience,
    resource = Resource,
    actions = Actions,
    expires_at = ExpiresAt,
    granted_at = GrantedAt
}) ->
    #{
        capability_id => CapId,
        issuer => Issuer,
        audience => Audience,
        resource => Resource,
        actions => Actions,
        expires_at => ExpiresAt,
        granted_at => GrantedAt
    }.

%% @doc Create command from map.
-spec from_map(map()) -> {ok, grant_capability_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    issuer := Issuer,
    audience := Audience,
    resource := Resource,
    actions := Actions,
    expires_at := ExpiresAt,
    granted_at := GrantedAt
}) ->
    {ok, #grant_capability_v1{
        capability_id = CapId,
        issuer = Issuer,
        audience = Audience,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt
    }};
from_map(_) ->
    {error, invalid_grant_capability_command}.

%% Accessor functions
get_capability_id(#grant_capability_v1{capability_id = C}) -> C.
get_issuer(#grant_capability_v1{issuer = I}) -> I.
get_audience(#grant_capability_v1{audience = A}) -> A.
get_resource(#grant_capability_v1{resource = R}) -> R.
get_actions(#grant_capability_v1{actions = A}) -> A.
get_expires_at(#grant_capability_v1{expires_at = E}) -> E.
get_granted_at(#grant_capability_v1{granted_at = G}) -> G.
