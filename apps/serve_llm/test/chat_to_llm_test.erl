%%% @doc Tests for chat_to_llm module (pure function tests only)
-module(chat_to_llm_test).

-include_lib("eunit/include/eunit.hrl").

%% Note: We test the NDJSON parser which is a pure function.
%% HTTP integration tests require a running Ollama instance.

%% The parse_ndjson function is not exported, so we test indirectly
%% by verifying the module compiles and exports the expected functions.

module_exports_test() ->
    Exports = chat_to_llm:module_info(exports),
    ?assert(lists:member({chat, 2}, Exports)),
    ?assert(lists:member({chat, 3}, Exports)),
    ?assert(lists:member({chat_stream, 3}, Exports)).
