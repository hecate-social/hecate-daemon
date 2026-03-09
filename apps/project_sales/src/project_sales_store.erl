%%% @doc ETS-backed read model facade for the sales domain.
%%%
%%% One named ETS table:
%%%   - sales (keyed by sale_id)
%%%
%%% Creates the table on start_link, then projections join it
%%% via evoq_read_model_ets shared named table support.
%%% @end
-module(project_sales_store).
-behaviour(gen_server).

-include_lib("guide_sale_lifecycle/include/sale_status.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2]).

%% Queries
-export([get_sale/1, list_sales/1]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(sales, [public, named_table, set, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

%% -- Queries --

-spec get_sale(binary()) -> {ok, map()} | {error, not_found}.
get_sale(SaleId) ->
    case ets:lookup(sales, SaleId) of
        [{_, Entry}] -> {ok, Entry};
        [] -> {error, not_found}
    end.

-spec list_sales(binary()) -> {ok, [map()]}.
list_sales(SellerId) ->
    All = ets:tab2list(sales),
    Matched = [E || {_K, #{seller_id := Sid} = E} <- All, Sid =:= SellerId],
    Sorted = lists:sort(fun(#{initiated_at := A}, #{initiated_at := B}) ->
        compare_desc(A, B)
    end, Matched),
    {ok, Sorted}.

%% -- Internal --

compare_desc(undefined, _) -> false;
compare_desc(_, undefined) -> true;
compare_desc(A, B) -> A >= B.
