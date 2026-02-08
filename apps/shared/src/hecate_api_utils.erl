%%% @doc Shared API utilities for Cowboy handlers.
%%%
%%% Common functions used by all API handlers across umbrella apps.
%%% This module has no dependencies on other Hecate apps.
%%% @end
-module(hecate_api_utils).

-export([json_response/3, json_ok/2, json_ok/3, json_error/3]).
-export([format_error/1]).
-export([method_not_allowed/1, not_found/1, bad_request/2]).
-export([read_json_body/1]).
-export([get_field/2, get_field/3]).

%% @doc Send a JSON response with status code.
-spec json_response(StatusCode :: non_neg_integer(), Body :: map(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_response(StatusCode, Body, Req0) ->
    JsonBody = json:encode(Body),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, JsonBody, Req0),
    {ok, Req, []}.

%% @doc Send a 200 OK response.
-spec json_ok(Result :: map(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_ok(Result, Req) ->
    json_response(200, maps:merge(#{ok => true}, Result), Req).

%% @doc Send OK response with custom status code.
-spec json_ok(StatusCode :: non_neg_integer(), Result :: map(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_ok(StatusCode, Result, Req) ->
    json_response(StatusCode, maps:merge(#{ok => true}, Result), Req).

%% @doc Send an error response.
-spec json_error(StatusCode :: non_neg_integer(), Reason :: term(), Req :: cowboy_req:req()) ->
    {ok, cowboy_req:req(), []}.
json_error(StatusCode, Reason, Req) ->
    json_response(StatusCode, #{ok => false, error => format_error(Reason)}, Req).

%% @doc 405 Method Not Allowed.
-spec method_not_allowed(Req :: cowboy_req:req()) -> {ok, cowboy_req:req(), []}.
method_not_allowed(Req) ->
    json_error(405, <<"Method not allowed">>, Req).

%% @doc 404 Not Found.
-spec not_found(Req :: cowboy_req:req()) -> {ok, cowboy_req:req(), []}.
not_found(Req) ->
    json_error(404, <<"Not found">>, Req).

%% @doc 400 Bad Request.
-spec bad_request(Reason :: term(), Req :: cowboy_req:req()) -> {ok, cowboy_req:req(), []}.
bad_request(Reason, Req) ->
    json_error(400, Reason, Req).

%% @doc Format error term to binary for JSON.
-spec format_error(term()) -> binary().
format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason);
format_error({Type, Details}) ->
    iolist_to_binary(io_lib:format("~p: ~p", [Type, Details]));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

%% @doc Read and decode JSON body from request.
-spec read_json_body(Req :: cowboy_req:req()) ->
    {ok, map(), cowboy_req:req()} | {error, invalid_json, cowboy_req:req()}.
read_json_body(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    try
        {ok, json:decode(Body), Req1}
    catch
        _:_ ->
            {error, invalid_json, Req1}
    end.

%% @doc Get field from map, supporting both atom and binary keys.
-spec get_field(Key :: atom(), Map :: map()) -> term().
get_field(Key, Map) ->
    get_field(Key, Map, undefined).

-spec get_field(Key :: atom(), Map :: map(), Default :: term()) -> term().
get_field(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    maps:get(Key, Map, maps:get(BinKey, Map, Default)).
