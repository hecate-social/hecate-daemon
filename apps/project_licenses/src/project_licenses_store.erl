%%% @doc ETS-backed read model facade for the licenses domain.
%%%
%%% Two named ETS tables:
%%%   - catalog  (keyed by plugin_id)
%%%   - licenses (keyed by license_id)
%%%
%%% Creates the tables on start_link, then projections join them
%%% via evoq_read_model_ets shared named table support.
%%% @end
-module(project_licenses_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2]).

%% Catalog queries
-export([get_catalog_entry/1, browse_catalog/1, get_seller_listings/1]).
%% License queries
-export([get_license/1, get_licenses_for_user/1, get_license_for_plugin/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(catalog, [public, named_table, set, {read_concurrency, true}]),
    ets:new(licenses, [public, named_table, set, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

%% -- Catalog queries --

get_catalog_entry(PluginId) ->
    case ets:lookup(catalog, PluginId) of
        [{_, Entry}] -> {ok, Entry};
        [] -> {error, not_found}
    end.

browse_catalog(UserId) ->
    All = ets:tab2list(catalog),
    Published = [E || {_K, #{status := S} = E} <- All, S band 4 =/= 0],
    Sorted = lists:sort(fun(#{name := A}, #{name := B}) -> A =< B end, Published),
    Items = [enrich_with_license(E, UserId) || E <- Sorted],
    {ok, Items}.

get_seller_listings(SellerId) ->
    All = ets:tab2list(catalog),
    Matched = [E || {_K, #{seller_id := Sid} = E} <- All, Sid =:= SellerId],
    Sorted = lists:sort(fun(#{cataloged_at := A}, #{cataloged_at := B}) ->
        compare_desc(A, B)
    end, Matched),
    {ok, Sorted}.

%% -- License queries --

get_license(LicenseId) ->
    case ets:lookup(licenses, LicenseId) of
        [{_, License}] -> {ok, License};
        [] -> {error, not_found}
    end.

get_licenses_for_user(UserId) ->
    All = ets:tab2list(licenses),
    Active = [L || {_K, #{user_id := Uid, status := S} = L} <- All,
              Uid =:= UserId, S band 32 =:= 0],
    {ok, Active}.

get_license_for_plugin(PluginId, UserId) ->
    All = ets:tab2list(licenses),
    case [L || {_K, #{plugin_id := PId, user_id := Uid, status := S} = L} <- All,
          PId =:= PluginId, Uid =:= UserId, S band 32 =:= 0] of
        [License | _] -> {ok, License};
        [] -> {error, not_found}
    end.

%% -- Internal --

enrich_with_license(CatalogEntry, UserId) ->
    PluginId = maps:get(plugin_id, CatalogEntry),
    case get_license_for_plugin(PluginId, UserId) of
        {ok, License} ->
            CatalogEntry#{
                license_id        => maps:get(license_id, License),
                installed         => maps:get(installed, License),
                installed_version => maps:get(installed_version, License)
            };
        {error, not_found} ->
            CatalogEntry#{
                license_id        => undefined,
                installed         => 0,
                installed_version => undefined
            }
    end.

compare_desc(undefined, _) -> false;
compare_desc(_, undefined) -> true;
compare_desc(A, B) -> A >= B.
