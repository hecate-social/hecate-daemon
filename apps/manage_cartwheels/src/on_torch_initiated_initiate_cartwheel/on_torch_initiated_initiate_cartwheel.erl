%%% @doc Process Manager: on_torch_initiated_initiate_cartwheel
%%%
%%% Reacts to torch_initiated_v1 events from the manage_torches domain
%%% and initiates a cartwheel in the manage_cartwheels domain.
%%%
%%% This follows the cross-domain integration pattern using process managers:
%%% - manage_torches emits torch_initiated_v1
%%% - This PM receives the event and dispatches initiate_cartwheel_v1
%%% - manage_cartwheels stores cartwheel_initiated_v1
%%%
%%% The PM lives in the target domain (manage_cartwheels) because it needs
%%% to know how to construct the target command.
-module(on_torch_initiated_initiate_cartwheel).
-behaviour(gen_server).

-export([start_link/0, handle_event/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Called when a torch_initiated_v1 event is detected.
%% This is the entry point for cross-domain integration.
%% Accepts both atom and binary keys for flexibility.
-spec handle_event(map()) -> ok.
handle_event(#{<<"event_type">> := <<"torch_initiated_v1">>} = Event) ->
    gen_server:cast(?SERVER, {torch_initiated, Event});
handle_event(#{event_type := <<"torch_initiated_v1">>} = Event) ->
    gen_server:cast(?SERVER, {torch_initiated, Event});
handle_event(_) ->
    ok.

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    logger:info("Process manager ~s started", [?MODULE]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast({torch_initiated, Event}, State) ->
    handle_torch_initiated(Event),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

%% @private
%% Extract fields from the event and initiate a cartwheel
handle_torch_initiated(Event) ->
    TorchId = get_field(torch_id, Event),
    Name = get_field(name, Event),
    Brief = get_field(brief, Event),

    %% Create the initiate_cartwheel command
    case initiate_cartwheel_v1:new(#{
        torch_id => TorchId,
        context_name => Name,
        description => Brief
    }) of
        {ok, Cmd} ->
            %% Dispatch via the handler (uses evoq for persistence)
            case maybe_initiate_cartwheel:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("Cartwheel initiated for torch ~s", [TorchId]);
                {error, Reason} ->
                    logger:error("Failed to initiate cartwheel for torch ~s: ~p",
                                [TorchId, Reason])
            end;
        {error, Reason} ->
            logger:error("Failed to create initiate_cartwheel command: ~p", [Reason])
    end.

%% @private
%% Get field from map supporting both atom and binary keys
get_field(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, Value} -> Value;
        error ->
            case maps:find(BinKey, Map) of
                {ok, Value} -> Value;
                error -> undefined
            end
    end.
