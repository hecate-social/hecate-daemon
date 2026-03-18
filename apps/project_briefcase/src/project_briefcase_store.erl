-module(project_briefcase_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([list_items/1, get_item/1, list_folders/0, list_children/1, count_children/1]).
-export([put_item/2, delete_item/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, briefcase_items).
-define(ARCHIVED, 8).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Query API (reads directly from public ETS)

list_items(Filters) ->
    All = ets:tab2list(?TABLE),
    Items = [I || {_K, I} <- All, not is_archived(I), apply_filters(I, Filters)],
    Sorted = lists:sort(fun(A, B) ->
        maps:get(updated_at, A, 0) >= maps:get(updated_at, B, 0)
    end, Items),
    {ok, Sorted}.

get_item(ItemId) ->
    case ets:lookup(?TABLE, ItemId) of
        [{_, Item}] -> {ok, Item};
        [] -> {error, not_found}
    end.

list_folders() ->
    All = ets:tab2list(?TABLE),
    {ok, [I || {_K, #{kind := <<"folder">>} = I} <- All, not is_archived(I)]}.

list_children(ParentId) ->
    All = ets:tab2list(?TABLE),
    {ok, [I || {_K, I} <- All, not is_archived(I), maps:get(parent_id, I, undefined) =:= ParentId]}.

count_children(ParentId) ->
    All = ets:tab2list(?TABLE),
    length([I || {_K, I} <- All, not is_archived(I), maps:get(parent_id, I, undefined) =:= ParentId]).

%% Write API (called by projection)

put_item(ItemId, Item) ->
    ets:insert(?TABLE, {ItemId, Item}),
    ok.

delete_item(ItemId) ->
    ets:delete(?TABLE, ItemId),
    ok.

%% gen_server

init([]) ->
    ?TABLE = ets:new(?TABLE, [set, public, named_table, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, {error, unknown_call}, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

is_archived(#{status := S}) -> S band ?ARCHIVED =/= 0;
is_archived(_) -> false.

apply_filters(Item, Filters) ->
    check_parent_id(Item, Filters) andalso
    check_kind(Item, Filters) andalso
    check_starred(Item, Filters) andalso
    check_search(Item, Filters) andalso
    check_file_type(Item, Filters).

check_parent_id(_Item, #{parent_id := <<"all">>}) -> true;
check_parent_id(Item, #{parent_id := Pid}) -> maps:get(parent_id, Item, undefined) =:= Pid;
check_parent_id(_Item, _) -> true.

check_kind(Item, #{kind := K}) -> maps:get(kind, Item) =:= K;
check_kind(_Item, _) -> true.

check_starred(Item, #{starred := true}) -> maps:get(starred, Item, false) =:= true;
check_starred(_Item, _) -> true.

check_search(Item, #{search := Q}) when is_binary(Q), byte_size(Q) > 0 ->
    Name = string:lowercase(maps:get(name, Item, <<>>)),
    binary:match(Name, string:lowercase(Q)) =/= nomatch;
check_search(_Item, _) -> true.

check_file_type(Item, #{file_type := T}) -> maps:get(file_type, Item, undefined) =:= T;
check_file_type(_Item, _) -> true.
