-module(venture_state).
-behaviour(gen_server).

-export([start_link/0]).
-export([
    record_venture_setup/2,
    record_venture_archived/1,
    record_discovery_started/1,
    record_division_discovered/3,
    record_discovery_completed/1,
    record_process_started/2,
    record_process_completed/2,
    record_incident_raised/1,
    get_venture_status/1,
    list_ventures/0
]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(TABLE, venture_progress).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Public API — all async except queries

record_venture_setup(VentureId, Name) ->
    gen_server:cast(?MODULE, {venture_setup, VentureId, Name}).

record_venture_archived(VentureId) ->
    gen_server:cast(?MODULE, {venture_archived, VentureId}).

record_discovery_started(VentureId) ->
    gen_server:cast(?MODULE, {discovery_started, VentureId}).

record_division_discovered(VentureId, DivisionId, Name) ->
    gen_server:cast(?MODULE, {division_discovered, VentureId, DivisionId, Name}).

record_discovery_completed(VentureId) ->
    gen_server:cast(?MODULE, {discovery_completed, VentureId}).

record_process_started(DivisionId, Process) ->
    gen_server:cast(?MODULE, {process_started, DivisionId, Process}).

record_process_completed(DivisionId, Process) ->
    gen_server:cast(?MODULE, {process_completed, DivisionId, Process}).

record_incident_raised(DivisionId) ->
    gen_server:cast(?MODULE, {incident_raised, DivisionId}).

get_venture_status(VentureId) ->
    gen_server:call(?MODULE, {get_status, VentureId}).

list_ventures() ->
    gen_server:call(?MODULE, list_ventures).

%% gen_server callbacks

init([]) ->
    ets:new(?TABLE, [named_table, set, public, {read_concurrency, true}]),
    {ok, #{}}.

handle_call({get_status, VentureId}, _From, State) ->
    Reply = do_get_status(VentureId),
    {reply, Reply, State};
handle_call(list_ventures, _From, State) ->
    Reply = do_list_ventures(),
    {reply, Reply, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({venture_setup, VentureId, Name}, State) ->
    Now = erlang:system_time(millisecond),
    ets:insert(?TABLE, {{venture, VentureId}, #{
        venture_id => VentureId,
        name => Name,
        phase => setup,
        status => active,
        division_count => 0,
        incident_count => 0,
        created_at => Now,
        updated_at => Now
    }}),
    {noreply, State};

handle_cast({venture_archived, VentureId}, State) ->
    update_venture(VentureId, fun(V) ->
        V#{status => archived, updated_at => erlang:system_time(millisecond)}
    end),
    {noreply, State};

handle_cast({discovery_started, VentureId}, State) ->
    update_venture(VentureId, fun(V) ->
        V#{phase => discovery, updated_at => erlang:system_time(millisecond)}
    end),
    {noreply, State};

handle_cast({division_discovered, VentureId, DivisionId, Name}, State) ->
    Now = erlang:system_time(millisecond),
    ets:insert(?TABLE, {{division, VentureId, DivisionId}, #{
        division_id => DivisionId,
        venture_id => VentureId,
        name => Name,
        current_process => discovered,
        processes => #{
            design => pending,
            plan => pending,
            generation => pending,
            testing => pending,
            deployment => pending,
            monitoring => pending,
            rescue => idle
        },
        incident_count => 0,
        created_at => Now,
        updated_at => Now
    }}),
    update_venture(VentureId, fun(V) ->
        V#{division_count => maps:get(division_count, V, 0) + 1, updated_at => Now}
    end),
    {noreply, State};

handle_cast({discovery_completed, VentureId}, State) ->
    update_venture(VentureId, fun(V) ->
        V#{phase => designing, updated_at => erlang:system_time(millisecond)}
    end),
    {noreply, State};

handle_cast({process_started, DivisionId, Process}, State) ->
    update_division_by_id(DivisionId, fun(D) ->
        Processes = maps:get(processes, D),
        D#{
            current_process => Process,
            processes => Processes#{Process => active},
            updated_at => erlang:system_time(millisecond)
        }
    end),
    {noreply, State};

handle_cast({process_completed, DivisionId, Process}, State) ->
    update_division_by_id(DivisionId, fun(D) ->
        Processes = maps:get(processes, D),
        D#{
            processes => Processes#{Process => completed},
            updated_at => erlang:system_time(millisecond)
        }
    end),
    {noreply, State};

handle_cast({incident_raised, DivisionId}, State) ->
    update_division_by_id(DivisionId, fun(D) ->
        Count = maps:get(incident_count, D, 0),
        D#{incident_count => Count + 1, updated_at => erlang:system_time(millisecond)}
    end),
    %% Also increment venture-level incident count
    case find_venture_for_division(DivisionId) of
        {ok, VentureId} ->
            update_venture(VentureId, fun(V) ->
                VC = maps:get(incident_count, V, 0),
                V#{incident_count => VC + 1, updated_at => erlang:system_time(millisecond)}
            end);
        not_found ->
            ok
    end,
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

%% Internal

update_venture(VentureId, Fun) ->
    case ets:lookup(?TABLE, {venture, VentureId}) of
        [{Key, Venture}] ->
            ets:insert(?TABLE, {Key, Fun(Venture)});
        [] ->
            ok
    end.

update_division_by_id(DivisionId, Fun) ->
    %% Scan for division by DivisionId (divisions keyed as {division, VentureId, DivisionId})
    case ets:match_object(?TABLE, {{division, '_', DivisionId}, '_'}) of
        [{Key, Division}] ->
            ets:insert(?TABLE, {Key, Fun(Division)});
        [] ->
            ok
    end.

find_venture_for_division(DivisionId) ->
    case ets:match(?TABLE, {{division, '$1', DivisionId}, '_'}) of
        [[VentureId]] -> {ok, VentureId};
        [] -> not_found
    end.

do_get_status(VentureId) ->
    case ets:lookup(?TABLE, {venture, VentureId}) of
        [{_, Venture}] ->
            %% Find all divisions for this venture
            Divisions = ets:match_object(?TABLE, {{division, VentureId, '_'}, '_'}),
            DivisionList = [DivInfo || {_, DivInfo} <- Divisions],
            {ok, Venture#{divisions => DivisionList}};
        [] ->
            {error, not_found}
    end.

do_list_ventures() ->
    Ventures = ets:match_object(?TABLE, {{venture, '_'}, '_'}),
    VentureList = [VInfo || {_, VInfo} <- Ventures],
    {ok, VentureList}.
