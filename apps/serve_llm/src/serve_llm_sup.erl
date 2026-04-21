%%% @doc serve_llm top-level supervisor
%%%
%%% Supervises emitters, pollers, and responders for the LLM domain.
-module(serve_llm_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% manage_providers: provider registry (must start before detect_llms)
        {manage_providers,
            {manage_providers, start_link, []},
            permanent, 5000, worker, [manage_providers]},

        %% detect_llms: polls local providers, emits llm_detected/removed events
        {detect_llms,
            {detect_llms, start_link, []},
            permanent, 5000, worker, [detect_llms]},

        %% chat_to_llm_responder: handles unary chat requests from mesh
        {chat_to_llm_responder,
            {chat_to_llm_responder, start_link, []},
            permanent, 5000, worker, [chat_to_llm_responder]},

        %% stream_chat_with_llm_sup: streaming chat (server-stream RPC)
        %% First Phase 4 pilot of PLAN_MACULA_STREAMING.md
        {stream_chat_with_llm_sup,
            {stream_chat_with_llm_sup, start_link, []},
            permanent, infinity, supervisor, [stream_chat_with_llm_sup]},

        %% get_available_llms_page_responder: handles list requests from mesh
        {get_available_llms_page_responder,
            {get_available_llms_page_responder, start_link, []},
            permanent, 5000, worker, [get_available_llms_page_responder]},

        %% check_llm_health_responder: handles health requests from mesh
        {check_llm_health_responder,
            {check_llm_health_responder, start_link, []},
            permanent, 5000, worker, [check_llm_health_responder]},

        %% report_llm_status: periodically checks model availability
        {report_llm_status,
            {report_llm_status, start_link, []},
            permanent, 5000, worker, [report_llm_status]}
    ],

    logger:info("[serve_llm] Supervisor started with ~p children", [length(Children)]),
    {ok, {SupFlags, Children}}.
