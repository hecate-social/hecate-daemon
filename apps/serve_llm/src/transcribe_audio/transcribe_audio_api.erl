%%% @doc Transcribe audio API handler.
%%%
%%% Handles POST /api/llm/audio/transcribe with multipart/form-data.
%%% Accepts an audio file and returns transcribed text via a
%%% Whisper-compatible STT endpoint.
%%%
%%% Form fields:
%%%   - file (required): Audio file binary
%%%   - provider (optional): Provider name, defaults to first available
%%%   - model (optional): STT model name
%%%   - language (optional): Language hint (ISO 639-1)
%%%
%%% Response:
%%%   {ok: true, text: "transcribed text"}
%%% @end
-module(transcribe_audio_api).

-export([init/2, routes/0]).

routes() -> [{"/api/llm/audio/transcribe", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_transcribe(Req0, State);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

handle_transcribe(Req0, _State) ->
    case read_multipart(Req0, #{}) of
        {ok, #{file := AudioBinary} = Fields, Req1} ->
            ProviderName = maps:get(provider, Fields, default_audio_provider()),
            Opts = build_opts(Fields),
            case manage_providers:get_provider(ProviderName) of
                {ok, {_Module, Config}} ->
                    case openai_provider:transcribe(Config, AudioBinary, Opts) of
                        {ok, Text} ->
                            hecate_api_utils:json_ok(#{text => Text}, Req1);
                        {error, {http_error, Status, Body}} ->
                            Msg = iolist_to_binary(
                                io_lib:format("STT provider returned HTTP ~B", [Status])),
                            logger:warning("[transcribe_audio] HTTP ~B: ~s", [Status, Body]),
                            hecate_api_utils:json_error(502, Msg, Req1);
                        {error, Reason} ->
                            hecate_api_utils:json_error(500, Reason, Req1)
                    end;
                {error, not_found} ->
                    hecate_api_utils:json_error(404,
                        <<"Audio provider not found">>, Req1)
            end;
        {ok, _Fields, Req1} ->
            hecate_api_utils:bad_request(<<"Missing audio file">>, Req1);
        {error, Reason, Req1} ->
            hecate_api_utils:bad_request(Reason, Req1)
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

read_multipart(Req0, Acc) ->
    case cowboy_req:read_part(Req0) of
        {ok, Headers, Req1} ->
            case cow_multipart:form_data(Headers) of
                {data, FieldName} ->
                    {ok, Body, Req2} = cowboy_req:read_part_body(Req1),
                    read_multipart(Req2, Acc#{binary_to_atom(FieldName) => Body});
                {file, _FieldName, _Filename, _ContentType} ->
                    {ok, Body, Req2} = read_full_part_body(Req1, <<>>),
                    read_multipart(Req2, Acc#{file => Body})
            end;
        {done, Req1} ->
            {ok, Acc, Req1}
    end.

read_full_part_body(Req0, Acc) ->
    case cowboy_req:read_part_body(Req0) of
        {ok, Body, Req1} ->
            {ok, <<Acc/binary, Body/binary>>, Req1};
        {more, Body, Req1} ->
            read_full_part_body(Req1, <<Acc/binary, Body/binary>>)
    end.

build_opts(Fields) ->
    Opts = #{},
    Opts1 = case maps:get(model, Fields, undefined) of
        undefined -> Opts;
        Model -> Opts#{model => Model}
    end,
    case maps:get(language, Fields, undefined) of
        undefined -> Opts1;
        Lang -> Opts1#{language => Lang}
    end.

default_audio_provider() ->
    Providers = manage_providers:list(),
    Preferred = [<<"groq">>, <<"openai">>],
    find_first_available(Preferred, Providers).

find_first_available([], _Providers) ->
    <<"groq">>;
find_first_available([Name | Rest], Providers) ->
    case maps:is_key(Name, Providers) of
        true -> Name;
        false -> find_first_available(Rest, Providers)
    end.
