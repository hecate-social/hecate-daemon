%%% @doc CT suite for the backlinks desk. PLAN PART1 §4.2.
%%%
%%% Phase 1.7: backlinks is a typed not-yet error (the SDK RME
%%% schema has no `path' field and there's no reverse index — see
%%% the module doc for why). These tests pin that contract so a
%%% future implementation doesn't silently regress to `[]'
%%% (which would be a lie: "no backlinks exist" vs the honest
%%% "I can't tell you yet").
%%% @end
-module(backlinks_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([returns_typed_not_implemented/1,
         function_is_exported_with_arity_2/1]).

all() ->
    [returns_typed_not_implemented,
     function_is_exported_with_arity_2].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

returns_typed_not_implemented(_Config) ->
    {error, backlinks_not_yet_implemented} =
        backlinks:backlinks(self(), <<"mri:user:io.x/acme/alice">>),
    {error, backlinks_not_yet_implemented} =
        resolve_mesh_names_api:backlinks(self(), <<"mri:station:abc">>),
    ok.

function_is_exported_with_arity_2(_Config) ->
    true = erlang:function_exported(backlinks, backlinks, 2),
    true = erlang:function_exported(resolve_mesh_names_api, backlinks, 2),
    ok.
