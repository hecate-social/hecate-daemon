%%% @doc LLM usage aggregate state record.

-record(llm_usage_state, {
    call_count = 0 :: non_neg_integer()
}).
