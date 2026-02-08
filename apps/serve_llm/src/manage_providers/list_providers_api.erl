%%% @doc API handler: GET /api/llm/providers
%%%
%%% List all configured LLM providers.
%%% @end
-module(list_providers_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Providers = manage_providers:list(),
    %% Convert to JSON-safe format (atoms to binaries)
    JsonProviders = maps:map(fun(_Name, Config) ->
        Type = maps:get(type, Config, unknown),
        Base = #{
            type => atom_to_binary(Type, utf8),
            enabled => maps:get(enabled, Config, true)
        },
        case maps:get(url, Config, undefined) of
            undefined -> Base;
            Url when is_list(Url) -> Base#{url => list_to_binary(Url)};
            Url -> Base#{url => Url}
        end
    end, Providers),
    hecate_api_utils:json_ok(#{providers => JsonProviders}, Req0).
