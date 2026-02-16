%%% @doc API handler: POST /api/llm/providers/add
%%%
%%% Add a new LLM provider.
%%% Body: {name, type, api_key?, url?}
%%% type must be one of: ollama, openai, anthropic, google
%%% @end
-module(add_provider_api).

-export([init/2, routes/0]).

routes() -> [{"/api/llm/providers/add", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            Name = hecate_api_utils:get_field(name, Params),
            TypeBin = hecate_api_utils:get_field(type, Params),
            ApiKey = hecate_api_utils:get_field(api_key, Params, <<>>),
            Url = hecate_api_utils:get_field(url, Params, <<>>),

            case validate_add_provider(Name, TypeBin) of
                {ok, Type} ->
                    Config = build_provider_config(Type, ApiKey, Url),
                    case manage_providers:add(Name, Type, Config) of
                        ok ->
                            manage_providers:refresh_models(),
                            hecate_api_utils:json_ok(#{}, Req1);
                        {error, Reason} ->
                            hecate_api_utils:bad_request(Reason, Req1)
                    end;
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

validate_add_provider(undefined, _) ->
    {error, <<"name is required">>};
validate_add_provider(_, undefined) ->
    {error, <<"type is required">>};
validate_add_provider(_, TypeBin) ->
    case TypeBin of
        <<"ollama">> -> {ok, ollama};
        <<"openai">> -> {ok, openai};
        <<"anthropic">> -> {ok, anthropic};
        <<"google">> -> {ok, google};
        _ -> {error, <<"type must be one of: ollama, openai, anthropic, google">>}
    end.

build_provider_config(ollama, _ApiKey, Url) ->
    case Url of
        <<>> -> #{};
        _ -> #{url => binary_to_list(Url)}
    end;
build_provider_config(Type, ApiKey, Url) ->
    DefaultUrl = default_url(Type),
    UrlStr = case Url of
        <<>> -> DefaultUrl;
        _ -> binary_to_list(Url)
    end,
    Base = #{url => UrlStr},
    case ApiKey of
        <<>> -> Base;
        _ -> Base#{api_key => ApiKey}
    end.

default_url(openai) -> "https://api.openai.com";
default_url(anthropic) -> "https://api.anthropic.com";
default_url(google) -> "https://generativelanguage.googleapis.com".
