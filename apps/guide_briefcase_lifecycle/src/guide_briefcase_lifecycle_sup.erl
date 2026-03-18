%%% @doc guide_briefcase_lifecycle top-level supervisor
%%%
%%% Supervises process managers that sync external plugin events
%%% with the Briefcase file index.
%%% @end
-module(guide_briefcase_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    %% Store opts point to the Scribe plugin's documents_store.
    %% The store only exists when Scribe is installed — the event handler
    %% will retry subscription until the store becomes available.
    ScribeStoreOpts = #{store_id => documents_store},

    Children = [
        %% PM: sync document rename from Scribe → Briefcase file name
        #{id => on_document_renamed_sync_file,
          start => {evoq_event_handler, start_link,
                    [on_document_renamed_sync_file, #{}, ScribeStoreOpts]},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
