%%% @doc Core LLM output translator.
%%%
%%% Stateless post-processor that normalizes raw LLM output into canonical
%%% structured formats. Supports rule-based extraction (fast, deterministic)
%%% and optional LLM-assisted refinement for semantic understanding.
%%%
%%% Usage:
%%%   translate_output:translate(RawContent, <<"vision_document">>)
%%%   translate_output:translate(RawContent, <<"knowledge_extraction">>, #{})
%%% @end
-module(translate_output).

-export([translate/2, translate/3]).

-spec translate(binary(), binary()) -> {ok, map()} | {error, term()}.
translate(RawContent, SchemaName) ->
    translate(RawContent, SchemaName, #{}).

-spec translate(binary(), binary(), map()) -> {ok, map()} | {error, term()}.
translate(RawContent, SchemaName, Opts) ->
    case translate_output_schemas:get(SchemaName) of
        {ok, #{requires_llm := false, extractor := ExtractFn}} ->
            ExtractFn(RawContent);
        {ok, #{requires_llm := true} = Schema} ->
            run_llm_extraction(RawContent, Schema, Opts);
        {error, _} = Err ->
            Err
    end.

%%% ===================================================================
%%% LLM-Assisted Extraction
%%% ===================================================================

run_llm_extraction(RawContent, Schema, Opts) ->
    ModelPref = maps:get(model_preference, Schema, <<"haiku">>),
    Prompt = maps:get(extraction_prompt, Schema, <<>>),

    %% Build extraction request
    Model = resolve_model(ModelPref, Opts),
    Messages = [
        #{role => <<"system">>, content => Prompt},
        #{role => <<"user">>, content => RawContent}
    ],
    ChatOpts = #{model => Model, temperature => 0.1},

    case chat_to_llm:chat(Model, Messages, ChatOpts) of
        {ok, Response} ->
            parse_llm_response(Response);
        {error, _} = Err ->
            Err
    end.

%% @doc Resolve model name from preference.
%% Caller can override via opts; otherwise pick a cheap model.
resolve_model(Preference, Opts) ->
    case maps:get(model, Opts, undefined) of
        undefined -> pick_cheap_model(Preference);
        Model -> Model
    end.

%% @doc Pick a cheap model for extraction tasks.
pick_cheap_model(<<"haiku">>) ->
    %% Try to find a small local model first, fall back to cloud
    case get_available_small_model() of
        {ok, Model} -> Model;
        error -> <<"claude-haiku-4-5-20251001">>
    end;
pick_cheap_model(Model) ->
    Model.

get_available_small_model() ->
    %% Check if any local models are available via Ollama
    case chat_to_llm:list_models() of
        {ok, Models} when is_list(Models), Models =/= [] ->
            %% Prefer small models for extraction
            SmallPrefs = [<<"llama3.2:1b">>, <<"llama3.2:3b">>,
                          <<"qwen2.5:3b">>, <<"phi3:mini">>],
            find_preferred(SmallPrefs, Models);
        _ ->
            error
    end.

find_preferred([], _Available) -> error;
find_preferred([Pref | Rest], Available) ->
    case lists:any(fun(M) ->
        Name = maps:get(name, M, maps:get(<<"name">>, M, <<>>)),
        Name =:= Pref
    end, Available) of
        true -> {ok, Pref};
        false -> find_preferred(Rest, Available)
    end.

%% @doc Parse LLM response to extract JSON structure.
parse_llm_response(Response) ->
    Content = extract_response_content(Response),
    JsonContent = extract_json_from_text(Content),
    case catch json:decode(JsonContent) of
        Decoded when is_map(Decoded) ->
            {ok, Decoded};
        _ ->
            %% Fallback: return raw content as insight
            {ok, #{
                entities => [],
                relationships => [],
                insights => [Content]
            }}
    end.

extract_response_content(#{<<"message">> := #{<<"content">> := C}}) -> C;
extract_response_content(#{message := #{content := C}}) -> C;
extract_response_content(#{<<"content">> := C}) -> C;
extract_response_content(#{content := C}) -> C;
extract_response_content(C) when is_binary(C) -> C;
extract_response_content(_) -> <<>>.

%% @doc Extract JSON from text that may contain markdown fences.
extract_json_from_text(Text) ->
    %% Try to find ```json ... ``` block first
    case binary:match(Text, <<"```json">>) of
        {Start, Len} ->
            AfterFence = binary:part(Text, Start + Len, byte_size(Text) - Start - Len),
            case binary:match(AfterFence, <<"```">>) of
                {End, _} ->
                    binary:part(AfterFence, 0, End);
                nomatch ->
                    AfterFence
            end;
        nomatch ->
            %% Try to find raw JSON (starts with { or [)
            find_json_start(Text)
    end.

find_json_start(Text) ->
    Trimmed = string:trim(Text),
    case Trimmed of
        <<"{", _/binary>> -> iolist_to_binary(Trimmed);
        <<"[", _/binary>> -> iolist_to_binary(Trimmed);
        _ -> iolist_to_binary(Trimmed)
    end.
