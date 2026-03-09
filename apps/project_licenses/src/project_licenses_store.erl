%%% @doc ETS-backed read model facade for the consumer licenses domain.
%%%
%%% Single named ETS table:
%%%   - licenses (keyed by license_id)
%%%
%%% Creates the table on start_link, then projections join it
%%% via evoq_read_model_ets shared named table support.
%%% @end
-module(project_licenses_store).
-behaviour(gen_server).

-include_lib("guide_license_lifecycle/include/license_status.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2]).

%% License queries
-export([get_license/1, get_licenses_for_user/1, get_license_for_plugin/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(licenses, [public, named_table, set, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

%% -- License queries --

get_license(LicenseId) ->
    case ets:lookup(licenses, LicenseId) of
        [{_, License}] -> {ok, License};
        [] -> {error, not_found}
    end.

get_licenses_for_user(ConsumerId) ->
    All = ets:tab2list(licenses),
    Active = [L || {_K, #{consumer_id := Cid, status := S} = L} <- All,
              Cid =:= ConsumerId, evoq_bit_flags:has_not(S, ?LIC_ARCHIVED)],
    {ok, Active}.

get_license_for_plugin(PluginId, ConsumerId) ->
    All = ets:tab2list(licenses),
    case [L || {_K, #{plugin_id := PId, consumer_id := Cid, status := S} = L} <- All,
          PId =:= PluginId, Cid =:= ConsumerId, evoq_bit_flags:has_not(S, ?LIC_ARCHIVED)] of
        [License | _] -> {ok, License};
        [] -> {error, not_found}
    end.
