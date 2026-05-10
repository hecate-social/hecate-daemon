%%% @doc Per-type rule for MRI type `station'. Phase 0 stub —
%%% see PLAN_DNS_OVER_MESH_PART1 §3 for the algebra.
%%% @end
-module(resolve_qname_station).

-export([resolve/2]).

%% Resolves the leftover qname labels (after stripping the type
%% discriminator + reverse-domain suffix) into the MRI's path
%% segments + realm.
-spec resolve(Labels :: [binary()], Realm :: binary()) ->
    {ok, binary()} | {error, atom()}.
resolve(_Labels, _Realm) ->
    {error, resolve_qname_station_not_yet_implemented}.
