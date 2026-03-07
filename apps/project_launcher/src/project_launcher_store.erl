%%% @doc ETS-backed read model facade for the launcher domain.
%%%
%%% Two named ETS tables:
%%%   - launcher_entries (keyed by entry_id)
%%%   - launcher_groups  (keyed by group name)
%%%
%%% Creates the tables on start_link, then projections join them
%%% via evoq_read_model_ets shared named table support.
%%% @end
-module(project_launcher_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2]).

%% Query functions
-export([list_entries/0, get_layout/0]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(launcher_entries, [public, named_table, set, {read_concurrency, true}]),
    ets:new(launcher_groups, [public, named_table, set, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

%% -- Queries --

list_entries() ->
    All = ets:tab2list(launcher_entries),
    Entries = [E || {_K, E} <- All],
    Sorted = lists:sort(fun(#{group_name := GA, position := PA},
                            #{group_name := GB, position := PB}) ->
        {GA, PA} =< {GB, PB}
    end, Entries),
    {ok, Sorted}.

get_layout() ->
    AllGroups = ets:tab2list(launcher_groups),
    Groups = [G || {_K, G} <- AllGroups],
    Sorted = lists:sort(fun(#{position := A}, #{position := B}) -> A =< B end, Groups),
    AllEntries = ets:tab2list(launcher_entries),
    Layout = lists:map(fun(#{name := Name} = Group) ->
        Entries = [E || {_K, #{group_name := GN} = E} <- AllEntries, GN =:= Name],
        SortedEntries = lists:sort(
            fun(#{position := A}, #{position := B}) -> A =< B end, Entries),
        Apps = [maps:get(entry_id, E) || E <- SortedEntries],
        #{
            name      => Name,
            icon      => maps:get(icon, Group),
            collapsed => maps:get(collapsed, Group),
            apps      => Apps
        }
    end, Sorted),
    {ok, Layout}.
