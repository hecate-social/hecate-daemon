%%% @doc GET /api/mesh/artifact/:hash — REQUESTER fetch by MCID.
%%%
%%% Read-only pull from the content-sharing fabric. No event sourcing:
%%% reads do not produce facts. Path binding is the hex-encoded MCID
%%% (34 bytes = 68 hex chars) as returned by `share_mesh_artifact_api'.
%%%
%%% Response:
%%%   #{ok => true, content => <<base64...>>, size_bytes => N}
%%% @end
-module(fetch_mesh_artifact_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/artifact/:hash", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Hash = cowboy_req:binding(hash, Req0),
    case decode_mcid(Hash) of
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req0);
        {ok, MCID} ->
            case hecate_mesh:get_content(MCID) of
                {ok, Bytes} ->
                    hecate_api_utils:json_ok(#{
                        content    => base64:encode(Bytes),
                        size_bytes => byte_size(Bytes)
                    }, Req0);
                {error, not_found} ->
                    hecate_api_utils:json_error(404, not_found, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(502, Reason, Req0)
            end
    end.

decode_mcid(undefined) -> {error, <<"hash is required">>};
decode_mcid(Hex) when is_binary(Hex), byte_size(Hex) =:= 68 ->
    try
        Bin = unhex(Hex),
        case Bin of
            <<1, 16#55, _:32/binary>> -> {ok, Bin};
            _ -> {error, <<"hash does not decode to a valid MCID">>}
        end
    catch
        _:_ -> {error, <<"hash must be hex">>}
    end;
decode_mcid(_) ->
    {error, <<"hash must be 68 hex chars (34-byte MCID)">>}.

unhex(<<>>) -> <<>>;
unhex(<<A, B, Rest/binary>>) ->
    <<(list_to_integer([A, B], 16)):8, (unhex(Rest))/binary>>.
