%%% @doc POST /api/mesh/artifact/put — Agent-facing artifact share.
%%%
%%% Request body:
%%%   #{<<"content">>      => <<"base64-encoded bytes">>,
%%%     <<"content_type">> => <<"text/plain">>}
%%%
%%% Response:
%%%   #{ok => true, mcid_hex => <<...>>, size_bytes => N, fact_id => <<...>>}
%%%
%%% The MCID is returned hex-encoded for ergonomic /api/mesh/artifact/:hash
%%% lookups; the raw 34-byte form is reconstructed on the GET side.
%%% @end
-module(share_mesh_artifact_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/artifact/put", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            dispatch(Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"invalid JSON">>, Req1)
    end.

dispatch(Body, Req) ->
    Content     = hecate_api_utils:get_field(content, Body),
    ContentType = hecate_api_utils:get_field(content_type, Body, <<"application/octet-stream">>),
    case decode(Content, ContentType) of
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req);
        {ok, Bytes, CT} ->
            RequestedAt = erlang:system_time(millisecond),
            Cmd = share_mesh_artifact_v1:new(Bytes, CT, RequestedAt),
            case maybe_share_mesh_artifact:dispatch(Cmd) of
                {ok, Version, Events} ->
                    MCID = extract_mcid(Events),
                    hecate_api_utils:json_ok(#{
                        mcid_hex   => to_hex(MCID),
                        size_bytes => byte_size(Bytes),
                        fact_id    => fact_id(Version)
                    }, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(502, Reason, Req)
            end
    end.

decode(undefined, _) -> {error, <<"content is required">>};
decode(_, CT) when not is_binary(CT) -> {error, <<"content_type must be a string">>};
decode(Content, CT) when is_binary(Content) ->
    try
        {ok, base64:decode(Content), CT}
    catch
        _:_ -> {error, <<"content must be base64-encoded">>}
    end;
decode(_, _) ->
    {error, <<"content must be a base64 string">>}.

extract_mcid([#{<<"mcid">> := MCID} | _]) -> MCID;
extract_mcid([#{mcid := MCID} | _])       -> MCID;
extract_mcid(_)                           -> <<>>.

to_hex(<<>>) -> <<>>;
to_hex(Bin) when is_binary(Bin) ->
    list_to_binary(lists:flatten(
        [io_lib:format("~2.16.0b", [B]) || <<B>> <= Bin])).

fact_id(Version) ->
    Stream = mesh_artifacts_aggregate:stream_id(),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).
