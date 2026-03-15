%%% @doc API handler: POST /api/llm/translate
%%%
%%% Translates raw LLM output into canonical structured formats.
%%%
%%% Request body:
%%%   - raw_content (required): Raw LLM output text
%%%   - schema (required): Schema name (e.g., "vision_document")
%%%   - opts (optional): Translation options
%%%
%%% Response:
%%%   {ok: true, result: <canonical map>}
%%% @end
-module(translate_output_api).

-export([init/2, routes/0]).

routes() -> [{"/api/llm/translate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            RawContent = maps:get(<<"raw_content">>, Params, undefined),
            Schema = maps:get(<<"schema">>, Params, undefined),
            Opts = maps:get(<<"opts">>, Params, #{}),
            do_translate(RawContent, Schema, Opts, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_translate(undefined, _, _, Req) ->
    hecate_api_utils:bad_request(<<"raw_content is required">>, Req);
do_translate(_, undefined, _, Req) ->
    hecate_api_utils:bad_request(<<"schema is required">>, Req);
do_translate(RawContent, Schema, Opts, Req) ->
    case translate_output:translate(RawContent, Schema, Opts) of
        {ok, Result} ->
            hecate_api_utils:json_ok(#{result => Result}, Req);
        {error, unknown_schema} ->
            hecate_api_utils:json_error(400, <<"Unknown schema">>, Req);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req)
    end.
