%%% @doc Synthesize speech API handler.
%%%
%%% Handles POST /api/llm/audio/speak with JSON body.
%%% Converts text to speech via a TTS endpoint and returns audio binary.
%%%
%%% Request body (JSON):
%%%   - text (required): Text to speak
%%%   - voice (optional): Voice name, defaults to "tara"
%%%   - provider (optional): Provider name, defaults to first available
%%%   - model (optional): TTS model name
%%%   - response_format (optional): Audio format, defaults to "wav"
%%%
%%% Response:
%%%   Binary audio with Content-Type: audio/wav (or matching format)
%%% @end
-module(synthesize_speech_api).

-export([init/2, routes/0]).

routes() -> [{"/api/llm/audio/speak", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_speak(Req0, State);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

handle_speak(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            Text = maps:get(<<"text">>, Params, undefined),
            case Text of
                undefined ->
                    hecate_api_utils:bad_request(<<"text is required">>, Req1);
                <<>> ->
                    hecate_api_utils:bad_request(<<"text cannot be empty">>, Req1);
                _ ->
                    Voice = maps:get(<<"voice">>, Params, <<"tara">>),
                    ProviderName = maps:get(<<"provider">>, Params, default_audio_provider()),
                    Opts = build_opts(Params),
                    do_speak(ProviderName, Text, Voice, Opts, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_speak(ProviderName, Text, Voice, Opts, Req) ->
    case manage_providers:get_provider(ProviderName) of
        {ok, {_Module, Config}} ->
            case openai_provider:speak(Config, Text, Voice, Opts) of
                {ok, AudioBinary} ->
                    Format = maps:get(response_format, Opts, <<"wav">>),
                    ContentType = audio_content_type(Format),
                    Req1 = cowboy_req:reply(200, #{
                        <<"content-type">> => ContentType,
                        <<"content-length">> => integer_to_binary(byte_size(AudioBinary))
                    }, AudioBinary, Req),
                    {ok, Req1, []};
                {error, {http_error, Status, Body}} ->
                    Msg = iolist_to_binary(
                        io_lib:format("TTS provider returned HTTP ~B", [Status])),
                    logger:warning("[synthesize_speech] HTTP ~B: ~s", [Status, Body]),
                    hecate_api_utils:json_error(502, Msg, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req)
            end;
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Audio provider not found">>, Req)
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

build_opts(Params) ->
    Opts = #{},
    Opts1 = case maps:get(<<"model">>, Params, undefined) of
        undefined -> Opts;
        Model -> Opts#{model => Model}
    end,
    case maps:get(<<"response_format">>, Params, undefined) of
        undefined -> Opts1;
        Format -> Opts1#{response_format => Format}
    end.

audio_content_type(<<"mp3">>) -> <<"audio/mpeg">>;
audio_content_type(<<"opus">>) -> <<"audio/opus">>;
audio_content_type(<<"aac">>) -> <<"audio/aac">>;
audio_content_type(<<"flac">>) -> <<"audio/flac">>;
audio_content_type(<<"pcm">>) -> <<"audio/pcm">>;
audio_content_type(_) -> <<"audio/wav">>.

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
